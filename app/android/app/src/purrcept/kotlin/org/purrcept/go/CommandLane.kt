package org.purrcept.go

import org.json.JSONObject
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * Owns one blocking Android wait, independently of the service's state executor. The state owner
 * calls every public method, journals before dispatch, and receives completion back on itself.
 * No second operation is queued behind an uncertain gesture. Tasks translate expected Android
 * failures into receipts; an unexpected programming failure remains an interrupted journal entry.
 */
class CommandLane(private val owner: Executor) {
    private val effects = Executors.newSingleThreadExecutor()
    private var busy = false
    private var closing = false
    private var identity: String? = null
    private var query: (() -> Unit)? = null

    /** Return false without invoking work when an earlier operation still owns the lane. */
    fun dispatch(identity: String, work: () -> JSONObject, complete: (JSONObject) -> Unit): Boolean {
        if (busy || closing) return false
        busy = true
        this.identity = identity
        effects.execute {
            var result: JSONObject? = null
            try { result = work() }
            finally {
                // An unexpected exception must not strand the lane. Its journal remains uncertain;
                // the exception still escapes this task rather than becoming a fictional receipt.
                val receipt = result
                owner.execute {
                    busy = false
                    this.identity = null
                    val pendingQuery = query
                    query = null
                    if (receipt != null) complete(receipt)
                    // The service journals completion before answering a query from a new connection.
                    pendingQuery?.invoke()
                }
            }
        }
        return true
    }

    /**
     * Defer a query of this actual in-flight command until its wait returns. At most one observer is
     * retained: a later authenticated connection replaces an obsolete one. The callback must recheck
     * its connection before reading the journal; this method never re-dispatches an operation.
     */
    fun deferQuery(identity: String, answer: () -> Unit): Boolean {
        if (this.identity != identity) return false
        query = answer
        return true
    }

    /**
     * Reject further dispatches and return resources on the owner after the real wait has ended.
     * The caller invokes this once during service destruction and revokes permission first;
     * cancellation cannot undo an accepted Android effect.
     */
    fun close(after: () -> Unit) {
        closing = true
        effects.execute { owner.execute(after) }
        effects.shutdown()
    }
}
