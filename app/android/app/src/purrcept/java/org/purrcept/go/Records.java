package org.purrcept.go;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import java.util.List;

/** DeviceService's serial executor is the only caller. UI events are published after commits. */
@Dao
public interface Records {
    @Insert(onConflict = OnConflictStrategy.REPLACE) void put(Record record);
    @Query("SELECT * FROM records WHERE id=:id") Record get(String id);
    @Query("SELECT * FROM records WHERE kind=:kind ORDER BY sequence,id") List<Record> list(String kind);
    @Query("DELETE FROM records WHERE id=:id") void delete(String id);
    @Query("DELETE FROM records") void clear();
}
