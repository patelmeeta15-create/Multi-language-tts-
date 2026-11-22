#!/bin/bash
mkdir -p app/src/main/java/com/ai/multitts app/src/main/res/xml

cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ai.multitts">
    <application android:allowBackup="true" android:extractNativeLibs="true" android:label="Multilingual AI TTS" android:theme="@android:style/Theme.Material.Light">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
            <intent-filter><action android:name="android.speech.tts.engine.CHECK_TTS_DATA" /><category android:name="android.intent.category.DEFAULT" /></intent-filter>
        </activity>
        <service android:name=".MultilingualTtsService" android:exported="true" android:label="Multilingual AI TTS">
            <intent-filter><action android:name="android.intent.action.TTS_SERVICE" /><category android:name="android.intent.category.DEFAULT" /></intent-filter>
            <meta-data android:name="android.speech.tts" android:resource="@xml/tts_engine" />
        </service>
    </application>
</manifest>
EOF

cat << 'EOF' > app/src/main/res/xml/tts_engine.xml
<?xml version="1.0" encoding="utf-8"?>
<tts-engine xmlns:android="http://schemas.android.com/apk/res/android" android:settingsActivity="com.ai.multitts.MainActivity" />
EOF

cat << 'EOF' > app/src/main/java/com/ai/multitts/MainActivity.kt
package com.ai.multitts

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.*
import kotlin.math.sin

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == TextToSpeech.Engine.ACTION_CHECK_TTS_DATA) {
            val i = Intent().apply {
                putStringArrayListExtra(TextToSpeech.Engine.EXTRA_AVAILABLE_VOICES, arrayListOf("guj-IND", "hin-IND", "san-IND", "eng-USA"))
                putStringArrayListExtra(TextToSpeech.Engine.EXTRA_UNAVAILABLE_VOICES, arrayListOf())
            }
            setResult(TextToSpeech.Engine.CHECK_VOICE_DATA_PASS, i)
            finish()
            return
        }
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(40, 40, 40, 40) }
        val statusText = TextView(this).apply { text = "તપાસી રહ્યું છે..."; textSize = 14f }
        Thread {
            val diag = MultilingualTtsService.initEngine(applicationContext)
            runOnUiThread { statusText.text = diag }
        }.start()
        val testInput = EditText(this).apply { setText("Hello world") }
        val speakBtn = Button(this).apply {
            text = "AI અવાજ ટેસ્ટ કરો (Direct Speak)"
            setOnClickListener {
                val txt = testInput.text.toString()
                statusText.text = "બનાવી રહ્યું છે..."
                Thread {
                    val res = MultilingualTtsService.speakDirectly(applicationContext, txt)
                    runOnUiThread { statusText.text = res }
                }.start()
            }
        }
        val beepBtn = Button(this).apply {
            text = "સ્પીકર બીપ ટેસ્ટ કરો (Beep)"
            setOnClickListener {
                Thread {
                    val sr = 22050
                    val s = FloatArray(sr / 2) { i -> (0.5 * sin(2.0 * Math.PI * 440.0 * i / sr)).toFloat() }
                    MultilingualTtsService.playPcm(s, sr)
                    runOnUiThread { statusText.text = "સ્પીકર બીપ વાગી!" }
                }.start()
            }
        }
        layout.addView(statusText)
        layout.addView(testInput)
        layout.addView(speakBtn)
        layout.addView(beepBtn)
        setContentView(ScrollView(this).apply { addView(layout) })
    }
}
EOF

cat << 'EOF' > app/src/main/java/com/ai/multitts/MultilingualTtsService.kt
package com.ai.multitts

import android.content.Context
import android.media.*
import android.speech.tts.*
import com.k2fsa.sherpa.onnx.*
import java.io.*

class MultilingualTtsService : TextToSpeechService() {
    companion object {
        private var gujTts: OfflineTts? = null
        private var engTts: OfflineTts? = null
        @Volatile private var isInit = false
        var lastStatus = "બાકી"

        @Synchronized
        fun initEngine(context: Context): String {
            if (isInit) return lastStatus
            try {
                val baseDir = File(context.filesDir, "models")
                val marker = File(baseDir, ".v5")
                if (!marker.exists()) {
                    baseDir.deleteRecursively()
                    copyAssets(context, "models", baseDir)
                    marker.createNewFile()
                }
                val gujDir = File(baseDir, "vits-mms-guj")
                val engDir = File(baseDir, "vits-piper-en_US-amy-medium")
                val tok = File(gujDir, "tokens.txt").takeIf { it.exists() }?.readLines()?.take(4)?.joinToString(",") ?: "no-tok"
                val phontab = File(engDir, "espeak-ng-data/phontab").exists()

                gujTts = OfflineTts(config = OfflineTtsConfig(model = OfflineTtsModelConfig(
                    vits = OfflineTtsVitsModelConfig(model = File(gujDir, "model.onnx").absolutePath, tokens = File(gujDir, "tokens.txt").absolutePath, dataDir = ""), numThreads = 2)))
                engTts = OfflineTts(config = OfflineTtsConfig(model = OfflineTtsModelConfig(
                    vits = OfflineTtsVitsModelConfig(model = File(engDir, "en_US-amy-medium.onnx").absolutePath, tokens = File(engDir, "tokens.txt").absolutePath, dataDir = File(engDir, "espeak-ng-data").absolutePath), numThreads = 2)))

                lastStatus = "Tok=[$tok] | Phontab=$phontab | GujSR=${gujTts?.sampleRate()} | EngSR=${engTts?.sampleRate()}"
                isInit = true
            } catch (e: Throwable) {
                lastStatus = "ક્રેશ: ${e.javaClass.simpleName}: ${e.message}"
            }
            return lastStatus
        }

        private fun copyAssets(context: Context, assetPath: String, outDir: File) {
            val list = context.assets.list(assetPath) ?: return
            if (list.isEmpty()) {
                outDir.parentFile?.mkdirs()
                context.assets.open(assetPath).use { i -> FileOutputStream(outDir).use { o -> i.copyTo(o) } }
            } else {
                outDir.mkdirs()
                for (item in list) copyAssets(context, "$assetPath/$item", File(outDir, item))
            }
        }

        fun speakDirectly(context: Context, text: String): String {
            val msg = initEngine(context)
            return try {
                val tts = if (text.any { it in '\u0A80'..'\u0AFF' }) gujTts else engTts ?: return "TTS null | $msg"
                val audio = tts!!.generate(text = text, sid = 0, speed = 1.0f)
                if (audio.samples.isNotEmpty()) {
                    playPcm(audio.samples, audio.sampleRate)
                    "સફળ! Samples=${audio.samples.size}"
                } else "0 samples | $msg"
            } catch (e: Throwable) { "એરર: ${e.message} | $msg" }
        }

        fun playPcm(samples: FloatArray, sr: Int) {
            val pcm = ShortArray(samples.size) { i -> (samples[i] * 32767.0f).toInt().coerceIn(-32768, 32767).toShort() }
            val buf = AudioTrack.getMinBufferSize(sr, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT).coerceAtLeast(pcm.size * 2)
            val track = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(sr).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setBufferSizeInBytes(buf).setTransferMode(AudioTrack.MODE_STATIC).build()
            track.write(pcm, 0, pcm.size); track.play()
            Thread.sleep(((pcm.size.toLong() * 1000L) / sr) + 150L)
            track.stop(); track.release()
        }
    }

    override fun onIsLanguageAvailable(l: String?, c: String?, v: String?) = TextToSpeech.LANG_COUNTRY_AVAILABLE
    override fun onGetLanguage() = arrayOf("guj", "IND", "")
    override fun onLoadLanguage(l: String?, c: String?, v: String?) = TextToSpeech.LANG_COUNTRY_AVAILABLE
    override fun onStop() {}
    override fun onSynthesizeText(req: SynthesisRequest?, cb: SynthesisCallback?) {
        val text = req?.charSequenceText?.toString()?.trim() ?: return
        if (cb == null) return
        if (!isInit) initEngine(applicationContext)
        val tts = if (text.any { it in '\u0A80'..'\u0AFF' }) gujTts else engTts
        val audio = tts?.generate(text = text, sid = 0, speed = 1.0f)
        if (audio != null && audio.samples.isNotEmpty()) {
            cb.start(audio.sampleRate, AudioFormat.ENCODING_PCM_16BIT, 1)
            val b = ByteArray(audio.samples.size * 2)
            for (i in audio.samples.indices) {
                val s = (audio.samples[i] * 32767.0f).toInt().coerceIn(-32768, 32767)
                b[i * 2] = (s and 0xFF).toByte(); b[i * 2 + 1] = ((s shr 8) and 0xFF).toByte()
            }
            cb.audioAvailable(b, 0, b.size)
        } else cb.start(22050, AudioFormat.ENCODING_PCM_16BIT, 1)
        cb.done()
    }
}
EOF

cat << 'EOF' > build.gradle
plugins {
    id 'com.android.application' version '8.2.0' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.20' apply false
}
EOF

mkdir -p app
cat << 'EOF' > app/build.gradle
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}
android {
    namespace 'com.ai.multitts'
    compileSdk 34
    defaultConfig {
        applicationId "com.ai.multitts"
        minSdk 24
        targetSdk 34
        versionCode 5
        versionName "5.0"
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = '17' }
    aaptOptions { noCompress "onnx", "txt", "bin" }
}
dependencies {
    implementation files("libs/sherpa-onnx.aar")
}
EOF

cat << 'EOF' > settings.gradle
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "MultilingualAITTS"
include ':app'
EOF

echo "Setup Complete!"
