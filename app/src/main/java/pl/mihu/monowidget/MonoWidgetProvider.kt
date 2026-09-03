package pl.mihu.monowidget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.Toast

class MonoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_TOGGLE) return

        when (MonoController.toggle(context)) {
            is MonoController.ToggleResult.Toggled -> Unit
            MonoController.ToggleResult.NoPermission -> {
                Toast.makeText(context, R.string.toast_no_permission, Toast.LENGTH_LONG).show()
                MonoController.openAccessibilitySettings(context)
            }
        }
        refreshAll(context)
    }

    companion object {
        const val ACTION_TOGGLE = "pl.mihu.monowidget.TOGGLE"

        /** Odswieza kazda instancje widgetu - wolane po toggle i z MainActivity.onResume(). */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MonoWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
        ) {
            val mono = MonoController.isMono(context)
            val views = RemoteViews(context.packageName, R.layout.widget_mono).apply {
                setImageViewResource(
                    R.id.widget_icon,
                    if (mono) R.drawable.ic_mono else R.drawable.ic_stereo,
                )
                setTextViewText(
                    R.id.widget_label,
                    context.getString(if (mono) R.string.state_mono else R.string.state_stereo),
                )
                setInt(
                    R.id.widget_root,
                    "setBackgroundResource",
                    if (mono) R.drawable.widget_bg_mono else R.drawable.widget_bg_stereo,
                )
                setContentDescription(
                    R.id.widget_root,
                    context.getString(
                        if (mono) R.string.cd_widget_mono else R.string.cd_widget_stereo
                    ),
                )
                setOnClickPendingIntent(R.id.widget_root, togglePendingIntent(context))
            }
            appWidgetManager.updateAppWidget(appWidgetIds, views)
        }

        private fun togglePendingIntent(context: Context): PendingIntent {
            // Intent jawny (ustawiony komponent) - receiver moze zostac exported="false".
            val intent = Intent(context, MonoWidgetProvider::class.java).setAction(ACTION_TOGGLE)
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
