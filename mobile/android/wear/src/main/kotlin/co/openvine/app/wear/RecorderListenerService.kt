// ABOUTME: Woken by the Data Layer when the phone's recorder opens, changes or closes
// ABOUTME: Keeps the ongoing activity that offers the remote in step with it

package co.openvine.app.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Offers the remote while the phone's camera is open, even when the watch app
 * is not running.
 */
class RecorderListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val latest = dataEvents
            .lastOrNull { it.dataItem.uri.path == RemoteProtocol.RECORDER_PATH }
            ?: return
        val recorder = if (latest.type == DataEvent.TYPE_DELETED) {
            null
        } else {
            val dataMap = DataMapItem.fromDataItem(latest.dataItem).dataMap
            RemoteProtocol.snapshot(dataMap.keySet().associateWith { dataMap.get<Any>(it) })
        }
        RemoteOngoingActivity.update(this, recorder)
    }
}
