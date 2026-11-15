package org.purrcept.go

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/** Exercises frame ownership across delayed events, replacement screens and UI discontinuities. */
class ScreenFrameTest {
    private val element = UiElementShape(
        path = listOf(0, 1), className = "Button", resourceId = "tab_chat",
        contentDigest = listOf(1.toByte()), bounds = listOf(0, 50, 100, 100), childCount = 0,
        clickable = true, editable = false, password = false, enabled = true,
        checked = false, selected = false,
    )
    private val tree = UiTreeShape(7, "org.purrcept.go", listOf(element), false)

    /** A fresh node instance with unchanged semantics survives benign content notifications. */
    @Test fun unchangedRecaptureKeepsFrameUsable() {
        val lease = ScreenFrame()
        val id = lease.publish(tree)
        lease.requireCurrent(id, tree.copy(elements = listOf(element.copy())))
        lease.requireCurrent(id, tree)
    }

    /** An old request cannot revoke the newer screen that replaced it. */
    @Test fun replacedFrameCannotInvalidateCurrentFrame() {
        val lease = ScreenFrame()
        val previous = lease.publish(tree)
        val current = lease.publish(tree)
        assertNotEquals(previous, current)
        assertThrows(IllegalStateException::class.java) { lease.requireCurrent(previous, tree) }
        lease.requireCurrent(current, tree)
    }

    /** Once a change is observed, returning to the old contents does not resurrect the lease. */
    @Test fun changedPageRequiresNewScreenEvenAfterReturning() {
        val lease = ScreenFrame()
        val id = lease.publish(tree)
        val changed = tree.copy(elements = listOf(element.copy(contentDigest = listOf(2.toByte()))))
        val rejection = assertThrows(StaleFrameException::class.java) { lease.requireCurrent(id, changed) }
        assertEquals("stale_frame", rejection.message)
        assertEquals("tree_changed", rejection.reason)
        val stillRejected = assertThrows(StaleFrameException::class.java) { lease.requireCurrent(id, tree) }
        assertEquals("tree_changed", stillRejected.reason)
        lease.requireCurrent(lease.publish(tree), tree)
    }

    /** Geometry, ancestry, identity and widget state all matter even when labels stay the same. */
    @Test fun changedTargetCannotReuseItsOldElementId() {
        val changes = listOf(
            element.copy(bounds = listOf(0, 150, 100, 200)),
            element.copy(path = listOf(1, 0)),
            element.copy(className = "EditText"),
            element.copy(resourceId = "delete"),
            element.copy(enabled = false),
            element.copy(selected = true),
            element.copy(password = true),
        )
        for (changed in changes) {
            val lease = ScreenFrame()
            val id = lease.publish(tree)
            assertThrows(IllegalStateException::class.java) {
                lease.requireCurrent(id, tree.copy(elements = listOf(changed)))
            }
        }
    }

    /** Windows and bounded traversal are part of frame identity, beyond visible labels. */
    @Test fun windowOrTraversalChangesExpireFrame() {
        for (changed in listOf(tree.copy(window = 8), tree.copy(packageName = "other"), tree.copy(truncated = true))) {
            val lease = ScreenFrame()
            val id = lease.publish(tree)
            assertThrows(IllegalStateException::class.java) { lease.requireCurrent(id, changed) }
        }
    }

    /** A different window's scroll cannot affect this frame's coordinates. */
    @Test fun onlyObservedWindowScrollRevokesFrame() {
        val lease = ScreenFrame()
        val id = lease.publish(tree)
        lease.scrolled(9)
        lease.requireCurrent(id, tree)
        lease.scrolled(7)
        val rejection = assertThrows(StaleFrameException::class.java) { lease.requireCurrent(id, tree) }
        assertEquals("window_scrolled", rejection.reason)
    }

    /** Unknown-window scrolling cannot be proven unrelated, so the caller must recapture. */
    @Test fun unknownWindowScrollRequiresNewScreen() {
        val lease = ScreenFrame()
        val id = lease.publish(tree)
        lease.scrolled(-1)
        assertThrows(IllegalStateException::class.java) { lease.requireCurrent(id, tree) }
    }

    /** Window transitions, interruption and accepted actions revoke even an unchanged tree. */
    @Test fun explicitRevocationCannotBeUndoneByRecaptureComparison() {
        val lease = ScreenFrame()
        val id = lease.publish(tree)
        lease.invalidate("operation_accepted")
        lease.invalidate("window_changed")
        val rejection = assertThrows(StaleFrameException::class.java) { lease.requireCurrent(id, tree) }
        assertEquals("operation_accepted", rejection.reason)
    }
}
