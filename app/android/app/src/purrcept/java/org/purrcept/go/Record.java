package org.purrcept.go;

import androidx.annotation.NonNull;
import androidx.room.Entity;
import androidx.room.PrimaryKey;

/** Durable local messages, pending sends, command receipts and the synchronization cursor. */
@Entity(tableName = "records")
public class Record {
    @PrimaryKey @NonNull public String id;
    @NonNull public String kind;
    @NonNull public String payload;
    public long sequence;
    public Record(@NonNull String id, @NonNull String kind, @NonNull String payload, long sequence) {
        this.id = id;
        this.kind = kind;
        this.payload = payload;
        this.sequence = sequence;
    }
}
