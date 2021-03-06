package org.videolan.vlc.android;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Stack;

import android.app.Notification;
import android.app.PendingIntent;
import android.app.Service;
import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.RemoteException;
import android.provider.MediaStore;
import android.util.Log;

public class AudioService extends Service {
    private static final String TAG = "VLC/AudioService";

    private static final int SHOW_PROGRESS = 0;

    private LibVLC mLibVLC;
    private ArrayList<Media> mMediaList;
    private ArrayList<Media> mPlayedMedia;
    private Stack<Media> mPrevious;
    private Media mCurrentMedia;
    private ArrayList<IAudioServiceCallback> mCallback;
    private EventManager mEventManager;
    private Notification mNotification;
    private boolean mShuffling = false;
    private boolean mRepeating = false;

    @Override
    public void onStart(Intent intent, int startId) {
        super.onStart(intent, startId);

        // Get libVLC instance
        try {
            mLibVLC = LibVLC.getInstance();
        } catch (LibVlcException e) {
            e.printStackTrace();
        }

        mCallback = new ArrayList<IAudioServiceCallback>();
        mMediaList = new ArrayList<Media>();
        mPlayedMedia = new ArrayList<Media>();
        mPrevious = new Stack<Media>();
        mEventManager = EventManager.getIntance();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mInterface;
    }

    /**
     * Handle libvlc asynchronous events
     */
    private Handler mEventHandler = new Handler() {

        @Override
        public void handleMessage(Message msg) {
            switch (msg.getData().getInt("event")) {
                case EventManager.MediaPlayerPlaying:
                    Log.e(TAG, "MediaPlayerPlaying");
                    break;
                case EventManager.MediaPlayerPaused:
                    Log.e(TAG, "MediaPlayerPaused");
                    executeUpdate();
                    // also hide notification if phone ringing
                    hideNotification();
                    break;
                case EventManager.MediaPlayerStopped:
                    Log.e(TAG, "MediaPlayerStopped");
                    executeUpdate();
                    break;
                case EventManager.MediaPlayerEndReached:
                    Log.e(TAG, "MediaPlayerEndReached");
                    executeUpdate();
                    next();
                    break;
                default:
                    Log.e(TAG, "Event not handled");
                    break;
            }
        }
    };

    private void executeUpdate() {
        for (int i = 0; i < mCallback.size(); i++) {
            try {
                mCallback.get(i).update();
            } catch (RemoteException e) {
                e.printStackTrace();
            }
        }
    }

    private Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case SHOW_PROGRESS:
                    int pos = (int) mLibVLC.getTime();
                    if (mCallback.size() > 0) {
                        executeUpdate();
                        mHandler.removeMessages(SHOW_PROGRESS);
                        sendEmptyMessageDelayed(SHOW_PROGRESS, 1000 - (pos % 1000));
                    }
                    break;
            }
        }
    };

    private void showNotification() {
        // add notification to status bar
        if (mNotification == null) {
            mNotification = new Notification(R.drawable.icon, null,
                    System.currentTimeMillis());
        }
        Intent notificationIntent = new Intent(this, MainActivity.class);
        notificationIntent.setAction(Intent.ACTION_MAIN);
        notificationIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        notificationIntent.putExtra(MainActivity.START_FROM_NOTIFICATION, "");
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, 0);
        mNotification.setLatestEventInfo(this, mCurrentMedia.getTitle(),
                mCurrentMedia.getArtist() + " - " + mCurrentMedia.getAlbum(), pendingIntent);
        startForeground(3, mNotification);

    }

    private void hideNotification() {
        mNotification = null;
        stopForeground(true);
    }

    private void pause() {
        mHandler.removeMessages(SHOW_PROGRESS);
        // hideNotification(); <-- see event handler
        mLibVLC.pause();
    }

    private void play() {
        mLibVLC.play();
        mHandler.sendEmptyMessage(SHOW_PROGRESS);
        showNotification();
    }

    private void stop() {
        mEventManager.removeHandler(mEventHandler);
        mLibVLC.stop();
        mCurrentMedia = null;
        mMediaList.clear();
        mPlayedMedia.clear();
        mPrevious.clear();
        mHandler.removeMessages(SHOW_PROGRESS);
        hideNotification();
        executeUpdate();
    }

    private void next() {
        int index = mMediaList.indexOf(mCurrentMedia);
        mPrevious.push(mCurrentMedia);
        if (mRepeating)
            mCurrentMedia = mMediaList.get(index);
        else if (mShuffling && mPlayedMedia.size() < mMediaList.size()) {
            while (mPlayedMedia.contains(mCurrentMedia = mMediaList
                           .get((int) (Math.random() * mMediaList.size()))))
                ;
        } else if (index < mMediaList.size() - 1) {
            mCurrentMedia = mMediaList.get(index + 1);
        } else {
            stop();
            return;
        }
        mLibVLC.readMedia(mCurrentMedia.getPath());
        showNotification();
    }

    private void previous() {
        int index = mMediaList.indexOf(mCurrentMedia);
        if (mPrevious.size() > 0)
            mCurrentMedia = mPrevious.pop();
        else if (index > 0)
            mCurrentMedia = mMediaList.get(index - 1);
        else
            return;
        mLibVLC.readMedia(mCurrentMedia.getPath());
        showNotification();
    }

    private void shuffle() {
        if (mShuffling)
            mPlayedMedia.clear();
        mShuffling = !mShuffling;
    }

    private void repeat() {
        mRepeating = !mRepeating;
    }

    private IAudioService.Stub mInterface = new IAudioService.Stub() {

        @Override
        public String getCurrentMediaPath() throws RemoteException {
            return mCurrentMedia.getPath();
        }

        @Override
        public void pause() throws RemoteException {
            AudioService.this.pause();
        }

        @Override
        public void play() throws RemoteException {
            AudioService.this.play();
        }

        @Override
        public void stop() throws RemoteException {
            AudioService.this.stop();
        }

        @Override
        public boolean isPlaying() throws RemoteException {
            return mLibVLC.isPlaying();
        }

        @Override
        public boolean isShuffling() {
            return mShuffling;
        }

        @Override
        public boolean isRepeating() {
            return mRepeating;
        }

        @Override
        public boolean hasMedia() throws RemoteException {
            return mMediaList.size() != 0;
        }

        @Override
        public String getAlbum() throws RemoteException {
            if (mCurrentMedia != null)
                return mCurrentMedia.getAlbum();
            else
                return null;
        }

        @Override
        public String getArtist() throws RemoteException {
            if (mCurrentMedia != null)
                return mCurrentMedia.getArtist();
            else
                return null;
        }

        @Override
        public String getTitle() throws RemoteException {
            if (mCurrentMedia != null)
                return mCurrentMedia.getTitle();
            else
                return null;
        }

        public Bitmap getCover() {
            if (mCurrentMedia != null) {
                try {
                    ContentResolver contentResolver = getContentResolver();
                    Uri uri = android.provider.MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI;
                    Cursor cursor = contentResolver.query(uri, new String[] {
                                   MediaStore.Audio.Albums.ALBUM,
                                   MediaStore.Audio.Albums.ALBUM_ART },
                                   MediaStore.Audio.Albums.ALBUM + " LIKE ?",
                                   new String[] { mCurrentMedia.getAlbum() }, null);
                    if (cursor == null) {
                        // do nothing
                    } else if (!cursor.moveToFirst()) {
                        // do nothing
                    } else {
                        int titleColumn = cursor.getColumnIndex(android.provider.MediaStore.Audio.Albums.ALBUM_ART);
                        String albumArt = cursor.getString(titleColumn);
                        Bitmap b = BitmapFactory.decodeFile(albumArt);
                        if (b != null)
                            return b;
                    }
                    File f = new File(mCurrentMedia.getPath());
                    for (File s : f.getParentFile().listFiles()) {
                        if (s.getAbsolutePath().endsWith("png") ||
                                s.getAbsolutePath().endsWith("jpg"))
                            return BitmapFactory.decodeFile(s.getAbsolutePath());
                    }
                } catch (Exception e) {
                }
            }
            return null;
        }

        @Override
        public void addAudioCallback(IAudioServiceCallback cb)
                throws RemoteException {
            mCallback.add(cb);
            executeUpdate();
        }

        @Override
        public void removeAudioCallback(IAudioServiceCallback cb)
                throws RemoteException {
            if (mCallback.contains(cb)) {
                mCallback.remove(cb);
            }
        }

        @Override
        public int getTime() throws RemoteException {
            return (int) mLibVLC.getTime();
        }

        @Override
        public int getLength() throws RemoteException {
            return (int) mLibVLC.getLength();
        }

        @Override
        public void load(List<String> mediaPathList, int position)
                throws RemoteException {
            mEventManager.addHandler(mEventHandler);
            mMediaList.clear();
            mPlayedMedia.clear();
            mPrevious.clear();
            DatabaseManager db = DatabaseManager.getInstance();
            for (int i = 0; i < mediaPathList.size(); i++) {
                String path = mediaPathList.get(i);
                Media media = db.getMedia(path);
                mMediaList.add(media);
            }

            if (mMediaList.size() > position) {
                mCurrentMedia = mMediaList.get(position);
            }

            mLibVLC.readMedia(mCurrentMedia.getPath());
            mHandler.sendEmptyMessage(SHOW_PROGRESS);
            showNotification();

        }

        @Override
        public void next() throws RemoteException {
            AudioService.this.next();
        }

        @Override
        public void previous() throws RemoteException {
            AudioService.this.previous();
        }

        public void shuffle() throws RemoteException {
            AudioService.this.shuffle();
        }

        @Override
        public void repeat() throws RemoteException {
            AudioService.this.repeat();
        }

        @Override
        public void setTime(long time) throws RemoteException {
            mLibVLC.setTime(time);
        }

        @Override
        public boolean hasNext() throws RemoteException {
            if (mRepeating)
                return false;
            int index = mMediaList.indexOf(mCurrentMedia);
            if (mShuffling && mPlayedMedia.size() < mMediaList.size() ||
                    index < mMediaList.size() - 1)
                return true;
            else
                return false;
        }

        @Override
        public boolean hasPrevious() throws RemoteException {
            if (mRepeating)
                return false;
            int index = mMediaList.indexOf(mCurrentMedia);
            if (mPrevious.size() > 0 || index > 0)
                return true;
            else
                return false;
        }
    };

}
