#!/bin/bash
mkdir -p app/src/main/java/com/ai/multitts app/src/main/res/xml

cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ai.multitts">
    <application android:allowBackup="true" android:extractNativeLibs="true" android:label="Multilingual AI TTS" android:theme="@android:style/Theme.Material.Light">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
            <intent-filter><action android:name="android.speech.tts.engine.CHECK_TTS_DATA" /><category android:name="android.intent.category.DEFAULT" /></intent-filter>
            <intent-filter><action android:name="android.speech.tts.engine.GET_SAMPLE_TEXT" /><category android:name="android.intent.category.DEFAULT" /></intent-filter>
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
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.*
import java.util.Locale

class MainActivity : Activity() {
    private var localTts: TextToSpeech? = null

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
        if (intent?.action == TextToSpeech.Engine.ACTION_GET_SAMPLE_TEXT) {
            val i = Intent().apply {
                putExtra(TextToSpeech.Engine.EXTRA_SAMPLE_TEXT, "નમસ્તે! આ ઓફલાઈન ગુજરાતી અને બહુભાષી AI અવાજ છે.")
            }
            setResult(RESULT_OK, i)
            finish()
            return
        }

        val prefs = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(44, 44, 44, 44) }
        val title = TextView(this).apply { text = "Multilingual AI TTS સેટિંગ્સ"; textSize = 20f }
        val statusText = TextView(this).apply { text = "AI અવાજો તૈયાર થઈ રહ્યા છે..."; textSize = 14f; setPadding(0, 16, 0, 20) }

        Thread {
            val diag = MultilingualTtsService.initEngine(applicationContext)
            runOnUiThread { statusText.text = diag }
        }.start()

        val speedLabel = TextView(this).apply {
            val sp = prefs.getInt("speech_speed", 100)
            text = "અવાજની ઝડપ (Speed): $sp%"
            textSize = 15f
        }
        val speedSeek = SeekBar(this).apply {
            max = 200
            progress = prefs.getInt("speech_speed", 100)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, p: Int, u: Boolean) {
                    val v = p.coerceAtLeast(50)
                    speedLabel.text = "અવાજની ઝડપ (Speed): $v%"
                    prefs.edit().putInt("speech_speed", v).apply()
                }
                override fun onStartTrackingTouch(sb: SeekBar?) {}
                override fun onStopTrackingTouch(sb: SeekBar?) {}
            })
        }

        val testInput = EditText(this).apply {
            setText("નમસ્તે! આ ઓફલાઈન ગુજરાતી અવાજ છે. नमस्ते हिंदी। Hello world!")
        }

        val directSpeakBtn = Button(this).apply {
            text = "સીધો AI અવાજ ટેસ્ટ કરો (Direct Speak)"
            setOnClickListener {
                val txt = testInput.text.toString()
                statusText.text = "અવાજ બનાવી રહ્યું છે..."
                Thread {
                    val res = MultilingualTtsService.speakDirectly(applicationContext, txt)
                    runOnUiThread { statusText.text = res }
                }.start()
            }
        }

        val sysSpeakBtn = Button(this).apply {
            text = "સિસ્ટમ TTS ટેસ્ટ કરો (System Speak)"
            setOnClickListener {
                val txt = testInput.text.toString()
                localTts?.shutdown()
                localTts = TextToSpeech(this@MainActivity, { st ->
                    if (st == TextToSpeech.SUCCESS) {
                        localTts?.language = Locale("gu", "IN")
                        localTts?.speak(txt, TextToSpeech.QUEUE_FLUSH, null, "t1")
                    } else statusText.text = "System TTS Error: $st"
                }, packageName)
            }
        }

        val settingsBtn = Button(this).apply {
            text = "ફોનના TTS સેટિંગ્સ ખોલો (TalkBack માટે પસંદ કરો)"
            setOnClickListener { startActivity(Intent("com.android.settings.TTS_SETTINGS")) }
        }

        layout.addView(title)
        layout.addView(statusText)
        layout.addView(speedLabel)
        layout.addView(speedSeek)
        layout.addView(testInput)
        layout.addView(directSpeakBtn)
        layout.addView(sysSpeakBtn)
        layout.addView(settingsBtn)
        setContentView(ScrollView(this).apply { addView(layout) })
    }

    override fun onDestroy() {
        localTts?.shutdown()
        super.onDestroy()
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
import java.util.Locale

class MultilingualTtsService : TextToSpeechService() {
    companion object {
        private var gujTts: OfflineTts? = null
        private var hinTts: OfflineTts? = null
        private var sanTts: OfflineTts? = null
        private var engTts: OfflineTts? = null
        @Volatile private var isInit = false
        var lastStatus = "પ્રારંભ બાકી"

        @Synchronized
        fun initEngine(context: Context): String {
            if (isInit && (engTts != null || hinTts != null || gujTts != null)) return lastStatus
            try {
                val baseDir = File(context.filesDir, "models")
                val marker = File(baseDir, ".v6")
                if (!marker.exists()) {
                    baseDir.deleteRecursively()
                    copyAssets(context, "models", baseDir)
                    marker.createNewFile()
                }

                val ok = mutableListOf<String>()
                val err = mutableListOf<String>()

                hinTts = safeLoad(File(baseDir, "vits-piper-hi_IN-rohan-medium"), "hi_IN-rohan-medium.onnx", "espeak-ng-data", "Hindi", ok, err)
                engTts = safeLoad(File(baseDir, "vits-piper-en_US-amy-medium"), "en_US-amy-medium.onnx", "espeak-ng-data", "English", ok, err)
                gujTts = safeLoad(File(baseDir, "vits-mms-guj"), "model.onnx", "", "Gujarati", ok, err)
                sanTts = safeLoad(File(baseDir, "vits-mms-san"), "model.onnx", "", "Sanskrit", ok, err)

                isInit = ok.isNotEmpty()
                lastStatus = if (ok.isNotEmpty()) {
                    "તૈયાર! ચાલુ અવાજો: ${ok.joinToString(", ")}" + (if (err.isNotEmpty()) "\nનોંધ: ${err.joinToString("; ")}" else "")
                } else {
                    "એરર: ${err.joinToString(" | ")}"
                }
            } catch (e: Throwable) {
                lastStatus = "ક્રેશ: ${e.message}"
            }
            return lastStatus
        }

        private fun safeLoad(dir: File, modelName: String, dataDir: String, label: String, ok: MutableList<String>, err: MutableList<String>): OfflineTts? {
            return try {
                val mf = File(dir, modelName)
                val tf = File(dir, "tokens.txt")
                if (!mf.exists() || !tf.exists()) {
                    err.add("$label ફાઈલ નથી")
                    return null
                }
                val cfg = OfflineTtsConfig(
                    model = OfflineTtsModelConfig(
                        vits = OfflineTtsVitsModelConfig(
                            model = mf.absolutePath,
                            tokens = tf.absolutePath,
                            dataDir = if (dataDir.isNotEmpty()) File(dir, dataDir).absolutePath else ""
                        ),
                        numThreads = 2
                    )
                )
                val tts = OfflineTts(config = cfg)
                ok.add(label)
                tts
            } catch (e: Throwable) {
                err.add("$label(${e.message})")
                null
            }
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

        // Gujarati/Devanagari phonetic fallback to Hindi Piper voice if MMS fails
        private fun gujToDevanagariPhonetic(text: String): String {
            val sb = StringBuilder()
            for (ch in text) {
                if (ch in '\u0A81'..'\u0AF9') {
                    sb.append((ch.code - 0x0A80 + 0x0900).toChar())
                } else {
                    sb.append(ch)
                }
            }
            return sb.toString()
        }

        fun splitByScript(text: String): List<Pair<String, String>> {
            val list = mutableListOf<Pair<String, String>>()
            val cur = StringBuilder()
            var curSc = ""
            for (ch in text) {
                val sc = when {
                    ch in '\u0A80'..'\u0AFF' -> "GUJ"
                    ch in '\u0900'..'\u097F' -> "DEV"
                    ch in 'A'..'Z' || ch in 'a'..'z' -> "ENG"
                    else -> curSc.ifEmpty { "ENG" }
                }
                if (curSc.isNotEmpty() && sc != curSc) {
                    val s = cur.toString().trim()
                    if (s.isNotEmpty()) list.add(curSc to s)
                    cur.clear()
                }
                curSc = sc
                cur.append(ch)
            }
            val last = cur.toString().trim()
            if (last.isNotEmpty()) list.add(curSc to last)
            return list
        }

        fun speakDirectly(context: Context, text: String): String {
            val msg = initEngine(context)
            if (!isInit) return msg
            val speed = (context.getSharedPreferences("tts_prefs", Context.MODE_PRIVATE).getInt("speech_speed", 100) / 100.0f).coerceIn(0.5f, 2.5f)
            var total = 0
            for ((sc, seg) in splitByScript(text)) {
                val (tts, finalTxt) = resolveEngine(sc, seg)
                if (tts == null) continue
                try {
                    val audio = tts.generate(text = finalTxt, sid = 0, speed = speed)
                    if (audio.samples.isNotEmpty()) {
                        total += audio.samples.size
                        playPcm(audio.samples, audio.sampleRate)
                    }
                } catch (e: Throwable) {
                    return "ઓડિયો એરર: ${e.message}"
                }
            }
            return if (total > 0) "અવાજ સફળતાપૂર્વક વાગ્યો! ($total samples)" else "0 samples બન્યા"
        }

        private fun resolveEngine(sc: String, seg: String): Pair<OfflineTts?, String> {
            return when (sc) {
                "GUJ" -> if (gujTts != null) gujTts to seg else hinTts to gujToDevanagariPhonetic(seg)
                "DEV" -> if (sanTts != null && (seg.contains("ः") || seg.contains("॥"))) sanTts to seg else hinTts to seg
                else -> engTts to seg
            }
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
    override fun onGetVoices(): MutableList<Voice> = mutableListOf(
        Voice("guj-IND-ai", Locale("gu", "IN"), Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet()),
        Voice("hin-IND-ai", Locale("hi", "IN"), Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet()),
        Voice("eng-USA-ai", Locale.US, Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet())
    )
    override fun onIsValidVoiceName(v: String?) = TextToSpeech.SUCCESS
    override fun onStop() {}

    override fun onSynthesizeText(req: SynthesisRequest?, cb: SynthesisCallback?) {
        val text = req?.charSequenceText?.toString()?.trim() ?: return
        if (cb == null) return
        if (!isInit) initEngine(applicationContext)
        val customSp = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE).getInt("speech_speed", 100) / 100.0f
        val speed = ((req.speechRate / 100.0f) * customSp).coerceIn(0.5f, 2.5f)
        var started = false
        try {
            for ((sc, seg) in splitByScript(text)) {
                val (tts, finalTxt) = resolveEngine(sc, seg)
                val audio = tts?.generate(text = finalTxt, sid = 0, speed = speed) ?: continue
                if (audio.samples.isEmpty()) continue
                if (!started) {
                    cb.start(audio.sampleRate, AudioFormat.ENCODING_PCM_16BIT, 1)
                    started = true
                }
                val b = ByteArray(audio.samples.size * 2)
                for (i in audio.samples.indices) {
                    val s = (audio.samples[i] * 32767.0f).toInt().coerceIn(-32768, 32767)
                    b[i * 2] = (s and 0xFF).toByte(); b[i * 2 + 1] = ((s shr 8) and 0xFF).toByte()
                }
                var off = 0
                while (off < b.size) {
                    val len = minOf(4096, b.size - off)
                    cb.audioAvailable(b, off, len)
                    off += len
                }
            }
            if (!started) cb.start(22050, AudioFormat.ENCODING_PCM_16BIT, 1)
            cb.done()
        } catch (e: Throwable) {
            cb.error()
        }
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
        versionCode 6
        versionName "6.0"
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
