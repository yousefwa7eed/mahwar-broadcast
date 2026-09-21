package com.example.mahwar

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {

    /**
     * يعيد محرك Flutter واحداً قابلاً لإعادة الاستخدام بدل إنشاء محرك جديد مع كل
     * نشاط: يُنشأ المحرك ويُخزَّن في FlutterEngineCache عند أول عملية تشغيل،
     * فإذا أُعيد إنشاء النشاط (إعدادات «Don't keep activities»/ضغط الذاكرة)
     * يظل المحرك وisolate دارت حيَّين وتُحفظ حالة التنقل والنماذج دون إعادة
     * تشغيل بارد إلى شاشة البداية.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val engineCache = FlutterEngineCache.getInstance()
        engineCache.get(CACHE_ENGINE_ID)?.let { return it }

        // FlutterEngine(context) يسجّل المكونات الإضافية تلقائياً عند الإنشاء
        // (automaticallyRegisterPlugins=true)، وconfigureFlutterEngine يتخطّى
        // التسجيل للمحركات المقدَّمة من المضيف — فلا يتكرر التسجيل.
        val engine = FlutterEngine(context.applicationContext)
        engineCache.put(CACHE_ENGINE_ID, engine)
        return engine
    }

    companion object {
        private const val CACHE_ENGINE_ID = "main_engine"
    }
}