package org.purrcept.go

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Exercise real executors: a blocked device must not block snapshots, queue another effect, or outlive storage. */
class CommandLaneTest {
    @Test fun stateStaysResponsiveAndClosureWaitsForRealCompletion() {
        val owner = Executors.newSingleThreadExecutor()
        val lane = CommandLane(owner)
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val completed = CompletableFuture<JSONObject>()
        val closed = CompletableFuture<Boolean>()
        val queried = CompletableFuture<Boolean>()
        try {
            assertTrue(owner.submit<Boolean> {
                lane.dispatch("original", {
                    started.countDown()
                    check(release.await(5, TimeUnit.SECONDS))
                    JSONObject().put("state", "confirmed")
                }) { completed.complete(it) }
            }.get(1, TimeUnit.SECONDS))
            assertTrue(started.await(1, TimeUnit.SECONDS))
            // A state read and a rejected overlapping dispatch both return while Android is waiting.
            assertEquals("thinking", owner.submit<String> { "thinking" }.get(1, TimeUnit.SECONDS))
            assertFalse(owner.submit<Boolean> {
                lane.dispatch("overlap", { error("must not run") }) { error("must not complete") }
            }.get(1, TimeUnit.SECONDS))
            owner.submit {
                assertFalse(lane.deferQuery("unrelated") { error("not owned") })
                assertTrue(lane.deferQuery("original") { error("obsolete connection") })
                assertTrue(lane.deferQuery("original") { queried.complete(completed.isDone) })
            }.get(1, TimeUnit.SECONDS)
            assertFalse(queried.isDone)
            owner.submit { lane.close { closed.complete(completed.isDone) } }.get(1, TimeUnit.SECONDS)
            assertFalse(closed.isDone)
            release.countDown()
            assertEquals("confirmed", completed.get(2, TimeUnit.SECONDS).getString("state"))
            assertTrue(closed.get(2, TimeUnit.SECONDS))
            assertTrue(queried.get(2, TimeUnit.SECONDS))
            assertFalse(owner.submit<Boolean> {
                lane.dispatch("closed", { error("closed") }) { error("closed") }
            }.get(1, TimeUnit.SECONDS))
        } finally {
            release.countDown()
            owner.shutdown()
            assertTrue(owner.awaitTermination(5, TimeUnit.SECONDS))
        }
    }
}
