package org.videolan.vlc.android;

import java.io.File;
import java.util.Comparator;
import java.util.List;

import android.content.Context;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.TextView;

public class BrowserAdapter extends ArrayAdapter<File>
                            implements Comparator<File> {
    public final static String TAG = "VLC/BrowserAdapter";

    public BrowserAdapter(Context context, int textViewResourceId) {
        super(context, textViewResourceId);
    }

    @Override
    public synchronized void add(File object) {
        super.add(object);
    }

    /**
     * Display the view of a file browser item.
     */
    @Override
    public View getView(int position, View convertView, ViewGroup parent) {

        ViewHolder holder;
        View view = convertView;
        if (view == null) {
            LayoutInflater inflater = (LayoutInflater) this.getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            view = inflater.inflate(R.layout.browser_item, parent, false);
            holder = new ViewHolder();
            holder.check = (CheckBox) view.findViewById(R.id.browser_item_selected);
            holder.text = (TextView) view.findViewById(R.id.browser_item_dir);
            view.setTag(holder);
        } else
            holder = (ViewHolder) view.getTag();

        final File item = getItem(position);
        final DatabaseManager dbManager = DatabaseManager.getInstance();

        if (item != null && item.getName() != null) {
            holder.text.setText(item.getName());
            holder.check.setOnCheckedChangeListener(null);
            holder.check.setTag(item);
            holder.check.setEnabled(true);
            holder.check.setChecked(false);

            List<File> dirs = dbManager.getMediaDirs();
            for (File dir : dirs) {
                if (dir.getPath().equals(item.getPath())) {
                    holder.check.setEnabled(true);
                    holder.check.setChecked(true);
                    break;
                } else if (dir.getPath().startsWith(item.getPath()+"/")) {
                    Log.i(TAG, dir.getPath() + " startWith " + item.getPath());
                    holder.check.setEnabled(false);
                    holder.check.setChecked(true);
                    break;
                }
            }

            holder.check.setOnCheckedChangeListener(onCheckedChangeListener);
        }

        return view;
    }

    private OnCheckedChangeListener onCheckedChangeListener = new OnCheckedChangeListener() {
        public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
            final DatabaseManager dbManager = DatabaseManager.getInstance();
            File item = (File) buttonView.getTag();
            if (item == null)
                return;

            if (buttonView.isEnabled() && isChecked) {
                dbManager.addDir(item.getPath());
                File tmpFile = item;
                while (!tmpFile.getPath().equals("/")) {
                    tmpFile = tmpFile.getParentFile();
                    dbManager.removeDir(tmpFile.getPath());
                }
            } else {
                dbManager.removeDir(item.getPath());
            }
        }
    };

    public void sort() {
        super.sort(this);
    }

    public int compare(File file1, File file2) {
        return file1.getName().toUpperCase().compareTo(
                file2.getName().toUpperCase());
    }

    static class ViewHolder {
        CheckBox check;
        TextView text;
    }
}
