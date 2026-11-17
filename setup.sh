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

# 3. MainActivity.kt (TalkBack Accessible UI + Sanskrit/Hindi Switch)
cat << 'EOF' > app/src/main/java/com/ai/multitts/MainActivity.kt
package com.ai.multitts

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle System TTS Data Check
        if (intent?.action == TextToSpeech.Engine.ACTION_CHECK_TTS_DATA) {
            val checkIntent = Intent()
            val voices = arrayListOf("guj-IND", "hin-IND", "san-IND", "eng-USA")
            checkIntent.putStringArrayListExtra(TextToSpeech.Engine.EXTRA_AVAILABLE_VOICES, voices)
            setResult(TextToSpeech.Engine.CHECK_VOICE_DATA_PASS, checkIntent)
            finish()
            return
        }

        val prefs = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "Multilingual Offline AI TTS (ગુજરાતી, हिन्दी, संस्कृतम्, English)"
            textSize = 20f
            contentDescription = "Multilingual Offline AI Text to Speech Settings"
        }

        val sanskritSwitch = Switch(this).apply {
            text = "દેવનાગરી લખાણ સંસ્કૃત (Sanskrit) અવાજમાં વાંચો"
            isChecked = prefs.getBoolean("prefer_sanskrit", false)
            setPadding(0, 32, 0, 32)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("prefer_sanskrit", isChecked).apply()
            }
        }

        val testInput = EditText(this).apply {
            hint = "ટેસ્ટ કરવા માટે અહીં લખો (ગુજરાતી, हिन्दी, संस्कृतम्, English)"
            setText("નમસ્તે! આ ઓફલાઈન AI અવાજ છે. सर्वे भवन्तु सुखिनः। Hello world!")
        }

        val openSettingsBtn = Button(this).apply {
            text = "ફોનના TTS સેટિંગ્સ ખોલો (TalkBack માટે પસંદ કરો)"
            setOnClickListener {
                startActivity(Intent("com.android.settings.TTS_SETTINGS"))
            }
        }

        layout.addView(title)
        layout.addView(sanskritSwitch)
        layout.addView(testInput)
        layout.addView(openSettingsBtn)
        setContentView(layout)
    }
}
EOF

# 4. MultilingualTtsService.kt (Smart Auto Language Detection & Sherpa-ONNX Engine)
cat << 'EOF' > app/src/main/java/com/ai/multitts/MultilingualTtsService.kt
package com.ai.multitts

import android.content.Context
import android.media.AudioFormat
import android.speech.tts.SynthesisCallback
import android.speech.tts.SynthesisRequest
import android.speech.tts.TextToSpeech
import android.speech.tts.TextToSpeechService
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import java.io.File
import java.io.FileOutputStream

class MultilingualTtsService : TextToSpeechService() {
    private var gujTts: OfflineTts? = null
    private var hinTts: OfflineTts? = null
    private var sanTts: OfflineTts? = null
    private var engTts: OfflineTts? = null

    override fun onCreate() {
        super.onCreate()
        initModels()
    }

    private fun initModels() {
        val baseDir = File(filesDir, "models")
        if (!baseDir.exists()) copyAssets("models", baseDir)

        gujTts = loadVitsModel(File(baseDir, "vits-mms-guj"), "model.onnx", "tokens.txt", "")
        sanTts = loadVitsModel(File(baseDir, "vits-mms-san"), "model.onnx", "tokens.txt", "")
        hinTts = loadVitsModel(File(baseDir, "vits-piper-hi_IN-rohan-medium"), "hi_IN-rohan-medium.onnx", "tokens.txt", "espeak-ng-data")
        engTts = loadVitsModel(File(baseDir, "vits-piper-en_US-amy-medium"), "en_US-amy-medium.onnx", "tokens.txt", "espeak-ng-data")
    }

    private fun loadVitsModel(dir: File, modelName: String, tokensName: String, dataDirName: String): OfflineTts? {
        return try {
            val modelFile = File(dir, modelName)
            if (!modelFile.exists()) return null
            val vitsConfig = OfflineTtsVitsModelConfig(
                model = modelFile.absolutePath,
                tokens = File(dir, tokensName).absolutePath,
                dataDir = if (dataDirName.isNotEmpty()) File(dir, dataDirName).absolutePath else ""
            )
            val modelConfig = OfflineTtsModelConfig(vits = vitsConfig, numThreads = 2)
            OfflineTts(config = OfflineTtsConfig(model = modelConfig))
        } catch (e: Exception) {
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
        return TextToSpeech.LANG_AVAILABLE
    }

    override fun onGetLanguage(): Array<String> = arrayOf("guj", "IND", "")

    override fun onLoadLanguage(lang: String?, country: String?, variant: String?): Int {
        return TextToSpeech.LANG_AVAILABLE
    }

    override fun onStop() {}

    override fun onSynthesizeText(request: SynthesisRequest?, callback: SynthesisCallback?) {
        val text = request?.charSequenceText?.toString()?.trim() ?: return
        if (text.isEmpty() || callback == null) return

        val prefs = getSharedPreferences("tts_prefs", Context.MODE_PRIVATE)
        val preferSanskrit = prefs.getBoolean("prefer_sanskrit", false)
        val speed = (request.speechRate / 100.0f).coerceIn(0.5f, 2.5f)

        // Smart Script Detection for TalkBack
        val selectedTts = when {
            text.any { it in '\u0A80'..'\u0AFF' } -> gujTts // Gujarati Unicode Block
            text.any { it in '\u0900'..'\u097F' } -> {        // Devanagari Unicode Block
                if (preferSanskrit || text.contains("ः") || text.contains("॥") || text.endsWith("म्")) sanTts else hinTts
            }
            else -> engTts
        } ?: engTts ?: gujTts

        if (selectedTts == null) {
            callback.done()
            return
        }

        val audio = selectedTts.generate(text = text, sid = 0, speed = speed)
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
    }
}
EOF

# 5. build.gradle (App level)
cat << 'EOF' > build.gradle
plugins {
    id 'com.android.application' version '8.2.0'
    id 'org.jetbrains.kotlin.android' version '1.9.22'
}

android {
    namespace 'com.ai.multitts'
    compileSdk 34

    defaultConfig {
        applicationId "com.ai.multitts"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
        ndk {
            abiFilters 'arm64-v8a'
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
    androidResources {
        noCompress 'onnx', 'ort', 'bin', 'txt'
    }
}

dependencies {
    implementation 'com.github.k2-fsa:sherpa-onnx:v1.10.28'
}
EOF

# 6. settings.gradle
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
        maven { url 'https://jitpack.io' }
    }
}
rootProject.name = "MultilingualAITTS"
include ':app'
EOF

mkdir -p app
mv build.gradle app/build.gradle
echo "Setup Complete!"
