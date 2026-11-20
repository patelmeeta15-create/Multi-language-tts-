#!/bin/bash
mkdir -p app/src/main/java/com/ai/multitts
mkdir -p app/src/main/res/xml
mkdir -p app/src/main/res/layout

# 1. AndroidManifest.xml (Includes Settings Gear Icon for System TTS)
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

# 2. tts_engine.xml (Enables Gear Icon next to Preferred Engine)
cat << 'EOF' > app/src/main/res/xml/tts_engine.xml
<?xml version="1.0" encoding="utf-8"?>
<tts-engine xmlns:android="http://schemas.android.com/apk/res/android"
    android:settingsActivity="com.ai.multitts.MainActivity" />
EOF

# 3. MainActivity.kt (Full Settings UI like Google TTS + Direct Voice Test)
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
import java.io.File
import java.util.Locale

class MainActivity : Activity() {
    private var localTts: TextToSpeech? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle System TTS Data Check
        if (intent?.action == TextToSpeech.Engine.ACTION_CHECK_TTS_DATA) {
            val checkIntent = Intent()
            val voices = arrayListOf("guj-IND", "hin-IND", "san-IND", "eng-USA")
            checkIntent.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_AVAILABLE_VOICES, voices)
            checkIntent.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_UNAVAILABLE_VOICES, arrayListOf())
            setResult(TextToSpeech.Engine.CHECK_VOICE_DATA_PASS, checkIntent)
            finish()
            return
        }

        // Handle Sample Text Request from System Settings
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
            setPadding(0, 0, 0, 24)
        }

        val statusText = TextView(this).apply {
            val modelsDir = File(filesDir, "models")
            val ready = modelsDir.exists() && (modelsDir.list()?.isNotEmpty() == true)
            text = if (ready) "એન્જિન સ્થિતિ: તૈયાર (Offline Models Loaded)" else "એન્જિન સ્થિતિ: પ્રથમ વખત લોડ થઈ રહ્યું છે..."
            textSize = 15f
            setPadding(0, 0, 0, 24)
        }

        // Language Mode Selection (Like Google TTS Voice Settings)
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

        // Speech Speed Control
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

        val speakBtn = Button(this).apply {
            text = "અવાજ ટેસ્ટ કરો (Speak Test)"
            setOnClickListener {
                val sample = testInput.text.toString()
                localTts?.shutdown()
                localTts = TextToSpeech(this@MainActivity, { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        localTts?.language = Locale("gu", "IN")
                        localTts?.speak(sample, TextToSpeech.QUEUE_FLUSH, null, "test_utterance")
                        statusText.text = "એન્જિન સ્થિતિ: અવાજ ચાલુ છે!"
                    } else {
                        statusText.text = "એન્જિન સ્થિતિ: એરર (Code: $status)"
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

# 4. MultilingualTtsService.kt (Thread-Safe Lazy Loading + Full Android Voice Support)
cat << 'EOF' > app/src/main/java/com/ai/multitts/MultilingualTtsService.kt
package com.ai.multitts

import android.content.Context
import android.media.AudioFormat
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
    private var gujTts: OfflineTts? = null
    private var hinTts: OfflineTts? = null
    private var sanTts: OfflineTts? = null
    private var engTts: OfflineTts? = null
    @Volatile private var isInitialized = false

    override fun onCreate() {
        super.onCreate()
        Thread { ensureModelsInitialized() }.start()
    }

    @Synchronized
    private fun ensureModelsInitialized() {
        if (isInitialized) return
        try {
            val baseDir = File(filesDir, "models")
            val markerFile = File(baseDir, ".extracted_ok")
            if (!markerFile.exists()) {
                copyAssets("models", baseDir)
                markerFile.createNewFile()
            }

            gujTts = loadVitsModel(File(baseDir, "vits-mms-guj"), "model.onnx", "tokens.txt", "")
            sanTts = loadVitsModel(File(baseDir, "vits-mms-san"), "model.onnx", "tokens.txt", "")
            hinTts = loadVitsModel(File(baseDir, "vits-piper-hi_IN-rohan-medium"), "hi_IN-rohan-medium.onnx", "tokens.txt", "espeak-ng-data")
            engTts = loadVitsModel(File(baseDir, "vits-piper-en_US-amy-medium"), "en_US-amy-medium.onnx", "tokens.txt", "espeak-ng-data")
            isInitialized = true
        } catch (e: Throwable) {
            Log.e("MultilingualTTS", "Init failed", e)
        }
    }

    private fun loadVitsModel(dir: File, modelName: String, tokensName: String, dataDirName: String): OfflineTts? {
        return try {
            val modelFile = File(dir, modelName)
            if (!modelFile.exists()) {
                Log.e("MultilingualTTS", "Missing model: ${modelFile.absolutePath}")
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
            Log.e("MultilingualTTS", "Error loading $modelName", e)
            null
        }
    }

    private fun copyAssets(assetPath: String, outDir: File) {
        val list = assets.list(assetPath) ?: return
        if (list.isEmpty()) {
            outDir.parentFile?.mkdirs()
            assets.open(assetPath).use { input ->
                FileOutputStream(outDir).use { output -> input.copyTo(output) }
            }
        } else {
            outDir.mkdirs()
            for (item in list) {
                copyAssets("$assetPath/$item", File(outDir, item))
            }
        }
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
            ensureModelsInitialized()
        }

        val prefs = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
        val preferSanskrit = prefs.getBoolean("prefer_sanskrit", false)
        val voiceMode = prefs.getInt("voice_mode", 0)
        val customSpeed = prefs.getInt("speech_speed", 100) / 100.0f
        val reqSpeed = (request.speechRate / 100.0f)
        val finalSpeed = (reqSpeed * customSpeed).coerceIn(0.5f, 2.5f)

        val selectedTts = when (voiceMode) {
            2 -> gujTts
            3 -> hinTts
            4 -> sanTts
            5 -> engTts
            else -> when {
                text.any { it in '\u0A80'..'\u0AFF' } -> gujTts
                text.any { it in '\u0900'..'\u097F' } -> {
                    if (voiceMode == 1 || preferSanskrit || text.contains("ः") || text.contains("॥") || text.endsWith("म्")) sanTts else hinTts
                }
                else -> engTts
            }
        } ?: gujTts ?: engTts ?: hinTts ?: sanTts

        if (selectedTts == null) {
            callback.error()
            return
        }

        try {
            val audio = selectedTts.generate(text = text, sid = 0, speed = finalSpeed)
            callback.start(audio.sampleRate, AudioFormat.ENCODING_PCM_16BIT, 1)

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
            callback.done()
        } catch (e: Throwable) {
            Log.e("MultilingualTTS", "Synthesis error", e)
            callback.error()
        }
    }
}
EOF

# 5. build.gradle (App level)
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
        versionCode 2
        versionName "2.0"
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
