在build.gradle中添加
``` kotlin
sourceSets {
    main {
        jniLibs.srcDirs = ['src/main/jniLibs']
    }
}

defaultConfig {
    minSdkVersion 19
    ndk {
        abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64'  // 正确的语法
    }
}
```
在build.gradle中添加
```kotlin
dependencies {
    implementation("net.java.dev.jna:jna:5.12.1")
    implementation("net.java.dev.jna:jna-platform:5.12.1")
}
packaging {
    resources {
        // 排除冲突的 META-INF 文件
        excludes.add("META-INF/AL2.0")
        excludes.add("META-INF/LGPL2.1")
        excludes.add("META-INF/LICENSE*")
        excludes.add("META-INF/NOTICE*")
    }
}
```