#!/bin/bash
mkdir -p app/src/main/java/com/ai/multitts
mkdir -p app/src/main/res/xml
mkdir -p app/src/main/res/layout

# 1. AndroidManifest.xml
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.ai.multitts">

    <application
        android:allowBackup="true"
        android:extractNativeLibs="true"
        android:label="Multilingual AI TTS"
        android:theme="@android:style/Theme.Material.Light">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.speech.tts.engine.CHECK_TTS_DATA" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.speech.tts.engine.GET_SAMPLE_TEXT" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.speech.tts.engine.INSTALL_TTS_DATA" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity>

        <service
            android:name=".MultilingualTtsService"
            android:exported="true"
            android:label="Multilingual AI TTS">
            <intent-filter>
                <action android:name="android.intent.action.TTS_SERVICE" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <meta-data
                android:name="android.speech.tts"
                android:resource="@xml/tts_engine" />
        </service>
    </application>
</manifest>
EOF

# 2. tts_engine.xml
cat << 'EOF' > app/src/main/res/xml/tts_engine.xml
<?xml version="1.0" encoding="utf-8"?>
<tts-engine xmlns:android="http://schemas.android.com/apk/res/android"
    android:settingsActivity="com.ai.multitts.MainActivity" />
EOF

# 3. MainActivity.kt
cat << 'EOF' > app/src/main/java/com/ai/multitts/MainActivity.kt
package com.ai.multitts

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import java.util.Locale

class MainActivity : Activity() {
    private var localTts: TextToSpeech? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == TextToSpeech.Engine.ACTION_CHECK_TTS_DATA) {
            val checkIntent = Intent()
            val voices = arrayListOf("guj-IND", "hin-IND", "san-IND", "eng-USA")
            checkIntent.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_AVAILABLE_VOICES, voices)
            checkIntent.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_UNAVAILABLE_VOICES, arrayListOf())
            setResult(TextToSpeech.Engine.CHECK_VOICE_DATA_PASS, checkIntent)
            finish()
            return
        }

        if (intent?.action == TextToSpeech.Engine.ACTION_GET_SAMPLE_TEXT) {
            val sampleIntent = Intent()
            sampleIntent.putExtra(
                TextToSpeech.Engine.EXTRA_SAMPLE_TEXT,
                "નમસ્તે! આ ઓફલાઈન ગુજરાતી અને બહુભાષી AI અવાજ છે."
            )
            setResult(RESULT_OK, sampleIntent)
            finish()
            return
        }

        val prefs = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
        val scroll = ScrollView(this)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "Multilingual AI TTS સેટિંગ્સ"
            textSize = 22f
            setPadding(0, 0, 0, 16)
        }

        val statusText = TextView(this).apply {
            text = "એન્જિન તપાસી રહ્યું છે..."
            textSize = 14f
            setPadding(0, 0, 0, 24)
        }

        Thread {
            val diag = MultilingualTtsService.initEngine(applicationContext)
            runOnUiThread {
                statusText.text = "સ્થિતિ: $diag"
            }
        }.start()

        val modeLabel = TextView(this).apply {
            text = "ભાષા અને અવાજ પસંદગી:"
            textSize = 16f
        }
        val modeSpinner = Spinner(this).apply {
            val options = arrayOf(
                "ઓટો-ડિટેક્ટ (ગુજરાતી + હિન્દી + અંગ્રેજી)",
                "ઓટો-ડિટેક્ટ (ગુજરાતી + સંસ્કૃત + અંગ્રેજી)",
                "ફક્ત ગુજરાતી (Gujarati AI)",
                "ફક્ત હિન્દી (Hindi AI)",
                "ફક્ત સંસ્કૃત (Sanskrit AI)",
                "ફક્ત અંગ્રેજી (English AI)"
            )
            adapter = ArrayAdapter(this@MainActivity, android.R.layout.simple_spinner_dropdown_item, options)
            setSelection(prefs.getInt("voice_mode", 0))
            onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: android.view.View?, pos: Int, id: Long) {
                    prefs.edit().putInt("voice_mode", pos).apply()
                }
                override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
            }
        }

        val sanskritSwitch = Switch(this).apply {
            text = "દેવનાગરી લખાણ સંસ્કૃત (Sanskrit) અવાજમાં વાંચો"
            isChecked = prefs.getBoolean("prefer_sanskrit", false)
            setPadding(0, 24, 0, 24)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("prefer_sanskrit", isChecked).apply()
            }
        }

        val speedLabel = TextView(this).apply {
            val savedSpeed = prefs.getInt("speech_speed", 100)
            text = "અવાજની ઝડપ (Speed): $savedSpeed%"
            textSize = 16f
        }
        val speedSeek = SeekBar(this).apply {
            max = 200
            progress = prefs.getInt("speech_speed", 100)
            setPadding(0, 12, 0, 24)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, p: Int, fromUser: Boolean) {
                    val valSpeed = p.coerceAtLeast(50)
                    speedLabel.text = "અવાજની ઝડપ (Speed): $valSpeed%"
                    prefs.edit().putInt("speech_speed", valSpeed).apply()
                }
                override fun onStartTrackingTouch(sb: SeekBar?) {}
                override fun onStopTrackingTouch(sb: SeekBar?) {}
            })
        }

        val testInput = EditText(this).apply {
            hint = "ટેસ્ટ કરવા માટે અહીં લખો"
            setText("નમસ્તે! આ ઓફલાઈન AI અવાજ છે. सर्वे भवन्तु सुखिनः। Hello world!")
        }

        val directSpeakBtn = Button(this).apply {
            text = "સીધો AI અવાજ ટેસ્ટ કરો (Direct Speak)"
            setOnClickListener {
                val sample = testInput.text.toString()
                statusText.text = "અવાજ બનાવી રહ્યું છે..."
                Thread {
                    val result = MultilingualTtsService.speakDirectly(applicationContext, sample)
                    runOnUiThread {
                        statusText.text = result
                    }
                }.start()
            }
        }

        val speakBtn = Button(this).apply {
            text = "સિસ્ટમ TTS ટેસ્ટ કરો (System Speak)"
            setOnClickListener {
                val sample = testInput.text.toString()
                localTts?.shutdown()
                localTts = TextToSpeech(this@MainActivity, { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        localTts?.language = Locale("gu", "IN")
                        localTts?.speak(sample, TextToSpeech.QUEUE_FLUSH, null, "test_utterance")
                    } else {
                        statusText.text = "System TTS એરર: Code $status"
                    }
                }, packageName)
            }
        }

        val openSettingsBtn = Button(this).apply {
            text = "ફોનના TTS સેટિંગ્સ ખોલો (TalkBack માટે પસંદ કરો)"
            setOnClickListener {
                startActivity(Intent("com.android.settings.TTS_SETTINGS"))
            }
        }

        layout.addView(title)
        layout.addView(statusText)
        layout.addView(modeLabel)
        layout.addView(modeSpinner)
        layout.addView(sanskritSwitch)
        layout.addView(speedLabel)
        layout.addView(speedSeek)
        layout.addView(testInput)
        layout.addView(directSpeakBtn)
        layout.addView(speakBtn)
        layout.addView(openSettingsBtn)
        scroll.addView(layout)
        setContentView(scroll)
    }

    override fun onDestroy() {
        localTts?.shutdown()
        super.onDestroy()
    }
}
EOF

# 4. MultilingualTtsService.kt
cat << 'EOF' > app/src/main/java/com/ai/multitts/MultilingualTtsService.kt
package com.ai.multitts

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.speech.tts.SynthesisCallback
import android.speech.tts.SynthesisRequest
import android.speech.tts.TextToSpeech
import android.speech.tts.TextToSpeechService
import android.speech.tts.Voice
import android.util.Log
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MultilingualTtsService : TextToSpeechService() {

    companion object {
        private var gujTts: OfflineTts? = null
        private var hinTts: OfflineTts? = null
        private var sanTts: OfflineTts? = null
        private var engTts: OfflineTts? = null
        @Volatile private var isInitialized = false
        var lastStatus: String = "પ્રારંભ બાકી"

        @Synchronized
        fun initEngine(context: Context): String {
            if (isInitialized && (gujTts != null || engTts != null)) {
                return lastStatus
            }
            try {
                val baseDir = File(context.filesDir, "models")
                val markerFile = File(baseDir, ".extracted_v2")
                if (!markerFile.exists()) {
                    baseDir.deleteRecursively()
                    copyAssets(context, "models", baseDir)
                    markerFile.createNewFile()
                }

                val errors = mutableListOf<String>()
                gujTts = loadVitsModel(File(baseDir, "vits-mms-guj"), "model.onnx", "tokens.txt", "", errors)
                sanTts = loadVitsModel(File(baseDir, "vits-mms-san"), "model.onnx", "tokens.txt", "", errors)
                hinTts = loadVitsModel(File(baseDir, "vits-piper-hi_IN-rohan-medium"), "hi_IN-rohan-medium.onnx", "tokens.txt", "espeak-ng-data", errors)
                engTts = loadVitsModel(File(baseDir, "vits-piper-en_US-amy-medium"), "en_US-amy-medium.onnx", "tokens.txt", "espeak-ng-data", errors)

                val loaded = listOfNotNull(
                    if (gujTts != null) "Guj" else null,
                    if (hinTts != null) "Hin" else null,
                    if (sanTts != null) "San" else null,
                    if (engTts != null) "Eng" else null
                )

                isInitialized = loaded.isNotEmpty()
                lastStatus = if (loaded.isNotEmpty()) {
                    "તૈયાર! લોડ થયેલ અવાજો: ${loaded.joinToString(", ")}"
                } else {
                    "એરર: ${errors.joinToString(" | ")}"
                }
            } catch (e: Throwable) {
                lastStatus = "ક્રેશ એરર: ${e.javaClass.simpleName}: ${e.message}"
                Log.e("MultilingualTTS", "Init failed", e)
            }
            return lastStatus
        }

        private fun loadVitsModel(
            dir: File,
            modelName: String,
            tokensName: String,
            dataDirName: String,
            errors: MutableList<String>
        ): OfflineTts? {
            return try {
                if (!dir.exists()) {
                    errors.add("${dir.name} ફોલ્ડર નથી")
                    return null
                }
                val modelFile = File(dir, modelName)
                if (!modelFile.exists()) {
                    val filesInside = dir.list()?.joinToString(",") ?: "empty"
                    errors.add("$modelName નથી (અંદર: $filesInside)")
                    return null
                }
                val vitsConfig = OfflineTtsVitsModelConfig(
                    model = modelFile.absolutePath,
                    tokens = File(dir, tokensName).absolutePath,
                    dataDir = if (dataDirName.isNotEmpty()) File(dir, dataDirName).absolutePath else ""
                )
                val modelConfig = OfflineTtsModelConfig(vits = vitsConfig, numThreads = 2)
                OfflineTts(config = OfflineTtsConfig(model = modelConfig))
            } catch (e: Throwable) {
                errors.add("${dir.name}: ${e.message}")
                Log.e("MultilingualTTS", "Error loading $modelName", e)
                null
            }
        }

        private fun copyAssets(context: Context, assetPath: String, outDir: File) {
            val list = context.assets.list(assetPath) ?: return
            if (list.isEmpty()) {
                outDir.parentFile?.mkdirs()
                context.assets.open(assetPath).use { input ->
                    FileOutputStream(outDir).use { output -> input.copyTo(output) }
                }
            } else {
                outDir.mkdirs()
                for (item in list) {
                    copyAssets(context, "$assetPath/$item", File(outDir, item))
                }
            }
        }

        fun splitByScript(text: String): List<Pair<String, String>> {
            val segments = mutableListOf<Pair<String, String>>()
            val current = StringBuilder()
            var currentScript = ""

            for (ch in text) {
                val script = when {
                    ch in '\u0A80'..'\u0AFF' -> "GUJ"
                    ch in '\u0900'..'\u097F' -> "DEV"
                    ch in 'A'..'Z' || ch in 'a'..'z' -> "ENG"
                    else -> currentScript.ifEmpty { "ENG" }
                }
                if (currentScript.isNotEmpty() && script != currentScript) {
                    val seg = current.toString().trim()
                    if (seg.isNotEmpty()) segments.add(currentScript to seg)
                    current.clear()
                }
                currentScript = script
                current.append(ch)
            }
            val lastSeg = current.toString().trim()
            if (lastSeg.isNotEmpty()) segments.add(currentScript to lastSeg)
            return segments
        }

        fun speakDirectly(context: Context, text: String): String {
            val status = initEngine(context)
            if (!isInitialized) return status

            val prefs = context.getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
            val preferSanskrit = prefs.getBoolean("prefer_sanskrit", false)
            val voiceMode = prefs.getInt("voice_mode", 0)
            val speed = (prefs.getInt("speech_speed", 100) / 100.0f).coerceIn(0.5f, 2.5f)

            val segments = splitByScript(text)
            var totalSamples = 0
            for ((script, segText) in segments) {
                val tts = pickTts(voiceMode, preferSanskrit, script, segText) ?: continue
                try {
                    val audio = tts.generate(text = segText, sid = 0, speed = speed)
                    if (audio.samples.isNotEmpty()) {
                        totalSamples += audio.samples.size
                        playPcm(audio.samples, audio.sampleRate)
                    }
                } catch (e: Throwable) {
                    return "ઓડિયો એરર ($script): ${e.message}"
                }
            }
            return if (totalSamples > 0) "અવાજ સફળતાપૂર્વક વાગ્યો! ($totalSamples samples)" else "ચેતવણી: 0 samples બન્યા"
        }

        private fun pickTts(voiceMode: Int, preferSanskrit: Boolean, script: String, segText: String): OfflineTts? {
            return when (voiceMode) {
                2 -> gujTts
                3 -> hinTts
                4 -> sanTts
                5 -> engTts
                else -> when (script) {
                    "GUJ" -> gujTts
                    "DEV" -> if (voiceMode == 1 || preferSanskrit || segText.contains("ः") || segText.contains("॥") || segText.endsWith("म्")) sanTts else hinTts
                    else -> engTts
                }
            } ?: gujTts ?: engTts ?: hinTts ?: sanTts
        }

        private fun playPcm(samples: FloatArray, sampleRate: Int) {
            val pcm = ShortArray(samples.size)
            for (i in samples.indices) {
                pcm[i] = (samples[i] * 32767.0f).toInt().coerceIn(-32768, 32767).toShort()
            }
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(pcm.size * 2)

            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(minBuf)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()

            track.write(pcm, 0, pcm.size)
            track.play()
            val durationMs = ((pcm.size.toLong() * 1000L) / sampleRate) + 150L
            Thread.sleep(durationMs)
            track.stop()
            track.release()
        }
    }

    override fun onCreate() {
        super.onCreate()
        Thread { initEngine(applicationContext) }.start()
    }

    override fun onIsLanguageAvailable(lang: String?, country: String?, variant: String?): Int {
        return TextToSpeech.LANG_COUNTRY_AVAILABLE
    }

    override fun onGetLanguage(): Array<String> = arrayOf("guj", "IND", "")

    override fun onLoadLanguage(lang: String?, country: String?, variant: String?): Int {
        return TextToSpeech.LANG_COUNTRY_AVAILABLE
    }

    override fun onGetVoices(): MutableList<Voice> {
        return mutableListOf(
            Voice("guj-IND-ai", Locale("gu", "IN"), Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet()),
            Voice("hin-IND-ai", Locale("hi", "IN"), Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet()),
            Voice("san-IND-ai", Locale("sa", "IN"), Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet()),
            Voice("eng-USA-ai", Locale.US, Voice.QUALITY_HIGH, Voice.LATENCY_NORMAL, false, emptySet())
        )
    }

    override fun onIsValidVoiceName(voiceName: String?): Int {
        return TextToSpeech.SUCCESS
    }

    override fun onStop() {}

    override fun onSynthesizeText(request: SynthesisRequest?, callback: SynthesisCallback?) {
        val text = request?.charSequenceText?.toString()?.trim() ?: return
        if (callback == null) return
        if (text.isEmpty()) {
            callback.start(22050, AudioFormat.ENCODING_PCM_16BIT, 1)
            callback.done()
            return
        }

        if (!isInitialized) {
            initEngine(applicationContext)
        }

        val prefs = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
        val preferSanskrit = prefs.getBoolean("prefer_sanskrit", false)
        val voiceMode = prefs.getInt("voice_mode", 0)
        val customSpeed = prefs.getInt("speech_speed", 100) / 100.0f
        val reqSpeed = (request.speechRate / 100.0f)
        val finalSpeed = (reqSpeed * customSpeed).coerceIn(0.5f, 2.5f)

        val segments = splitByScript(text)
        var started = false

        try {
            for ((script, segText) in segments) {
                val tts = pickTts(voiceMode, preferSanskrit, script, segText) ?: continue
                val audio = tts.generate(text = segText, sid = 0, speed = finalSpeed)
                if (audio.samples.isEmpty()) continue

                if (!started) {
                    callback.start(audio.sampleRate, AudioFormat.ENCODING_PCM_16BIT, 1)
                    started = true
                }

                val pcmData = ByteArray(audio.samples.size * 2)
                for (i in audio.samples.indices) {
                    val sample = (audio.samples[i] * 32767.0f).toInt().coerceIn(-32768, 32767)
                    pcmData[i * 2] = (sample and 0xFF).toByte()
                    pcmData[i * 2 + 1] = ((sample shr 8) and 0xFF).toByte()
                }

                var offset = 0
                val chunkSize = 4096
                while (offset < pcmData.size) {
                    val len = minOf(chunkSize, pcmData.size - offset)
                    callback.audioAvailable(pcmData, offset, len)
                    offset += len
                }
            }
            if (!started) {
                callback.start(22050, AudioFormat.ENCODING_PCM_16BIT, 1)
            }
            callback.done()
        } catch (e: Throwable) {
            Log.e("MultilingualTTS", "Synthesis error", e)
            callback.error()
        }
    }
}
EOF

# 5. build.gradle
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
        versionCode 3
        versionName "3.0"
    }

    buildTypes {
        release {
            minifyEnabled false
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
    aaptOptions {
        noCompress "onnx", "txt", "bin"
    }
}

dependencies {
    implementation files("libs/sherpa-onnx.aar")
}
EOF

cat << 'EOF' > settings.gradle
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "MultilingualAITTS"
include ':app'
EOF

echo "Setup Complete!"
