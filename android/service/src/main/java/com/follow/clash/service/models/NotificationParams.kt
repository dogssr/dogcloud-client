package com.follow.clash.service.models

data class NotificationParams(
    val title: String = "狗云加速器",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
