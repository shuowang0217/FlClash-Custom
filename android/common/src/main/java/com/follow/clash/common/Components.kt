package com.follow.clash.common

import android.content.ComponentName

object Components {
    // Kotlin classes keep the upstream namespace so Android manifests and
    // component class names remain resolvable after changing applicationId.
    const val PACKAGE_NAME = "com.follow.clash"

    // Dart MethodChannels and native plugins must agree on this stable name,
    // independently of the debug .dev applicationId suffix.
    const val FLUTTER_CHANNEL_NAMESPACE = "com.shuowang.flclash.custom"

    val mainActivity =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.MainActivity")

    val quickActionActivity =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.QuickActionActivity")

    val serviceBroadcastReceiver =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.ServiceBroadcastReceiver")
}
