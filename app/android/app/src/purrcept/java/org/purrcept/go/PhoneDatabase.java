package org.purrcept.go;

import androidx.room.Database;
import androidx.room.RoomDatabase;

/** DeviceService owns this cache. Engine remains the authority for admitted inputs. */
@Database(entities = {Record.class}, version = 1, exportSchema = false)
public abstract class PhoneDatabase extends RoomDatabase {
    public abstract Records records();
}
