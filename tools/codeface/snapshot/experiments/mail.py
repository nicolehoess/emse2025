import argparse
import glob
import urllib.request
import os
import re
import shutil

from datetime import datetime


def arguments():
    """Command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--mbox_archive", required=True,
                        help="Remote archive to download the mailboxes from, \
                             currently supports \
                             gnu (https://lists.gnu.org/archive/mbox/) and \
                             pipermail (https://<project-website>/pipermail/) and \
                             apache ('https://mail-archives.apache.org/mod_mbox/')")
    parser.add_argument("--list_name", required=True,
                        help="Mailing list name in the archive, e.g. qemu-devel")
    parser.add_argument("--save_path", required=True,
                        help="Local path to the directory to store the mailboxes")
    parser.add_argument("--start_year", required=True, 
                        help="Year to start querying the mailing list archive")
    parser.add_argument("--end_year", required=True, 
                        help="Year to end querying the mailing list archive")
    parser.add_argument("--download", required=False, action="store_true",
                        help="Download all mailboxes to the given directory")
    parser.add_argument("--rename", required=False, action="store_true",
                        help="Rename all manually downloaded mailboxes in the given directory")
    parser.add_argument("--convert", required=False, action="store_true",
                        help="Convert mailboxes in .txt.gz format to .mbox")
    parser.add_argument("--concat", required=False, action="store_true",
                        help="Concat all mailboxes to a single archive")
    parser.add_argument("--rm_pre", required=False, action="store_true",
                        help="Clean download directory before downloading")
    parser.add_argument("--rm_post", required=False, action="store_true",
                        help="Remove individual mailboxes after concatenating")
    return parser.parse_args()


def download_mbox(mbox_archive, list_name, save_path, start_year, end_year):
    """Downloads all mailboxes from the given remote archive."""
    
    mbox_archive = mbox_archive + list_name + "/"
    years = range(start_year, end_year+1)
    months = range(1, 12+1)

    for y in years:
        for m in months:
            # Local name scheme: list-name_YYYY_mm.mbox
            local_str = str(y)+"-"+str(m).zfill(2)
            mbox_name = list_name+"_"+local_str

            # Archive-specific name schemes
            if "pipermail" in mbox_archive:
                # Pipermail scheme: YYYY-month.txt.gz
                month_names = ["January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"]
                archive_str = str(y)+"-"+month_names[m-1]+".txt.gz"
                mbox_path = os.path.join(save_path, mbox_name+".txt.gz")
            elif "lists.gnu.org" in mbox_archive:
                # GNU lists scheme: YYYY-MM.mbox
                archive_str = local_str
                mbox_path = os.path.join(save_path, mbox_name+".mbox")
            elif "mail-archives.apache.org" in mbox_archive:
                # Apache lists scheme: YYYY-MM.mbox
                archive_str = str(y)+str(m).zfill(2)+".mbox"
                mbox_path = os.path.join(save_path, mbox_name+".mbox")

            # Download and store mailbox from remote archive
            mbox_url =  mbox_archive + archive_str
            print("Downloading: " + mbox_url + " ...")
            try:
                urllib.request.urlretrieve(mbox_url, mbox_path)
                print("- Done")
            except:
                print("- Could not retrieve mailbox for " + local_str)


def convert_mbox(list_name, save_path, start_year, end_year):
    """Converts mailboxes in .txt.gz format (as given by pipermail) to .mbox."""

    escaped_list_name = re.escape(list_name)
    out_path = os.path.join(save_path, list_name+".mbox")
    years = range(start_year, end_year+1)
    months = range(1, 12+1)

    with open(out_path, "wb") as out_file:
        for y in years:
            for m in months:
                postfix = str(y)+"-"+str(m).zfill(2)
                mbox_name = list_name+"_"+postfix
                tz_path = os.path.join(save_path, mbox_name+".txt.gz")
                txt_path = os.path.join(save_path, mbox_name+".txt")
                out_path = os.path.join(save_path, mbox_name+".mbox")

                if os.path.exists(tz_path):
                    # Unzip and open original file
                    import gzip
                    with gzip.open(tz_path, "rb") as f:
                        content = f.readlines()

                    # Store as .mbox file and replace "@" in addresses
                    with open(out_path, 'w') as f:
                        for line in content:
                            line = line.decode("latin-1")
                            # TODO: maybe we also have to change the format to: First Last <e-mail>?
                            # From: XXX at XXX
                            line = re.sub(r"From:\s+(.*?)\s+at\s+(.*)", r"From: \1@\2", line, count=0)
                            # From XXX at XXX
                            line = re.sub(r"From\s+(.*?)\s+at\s+(.*)", r"From \1@\2", line, count=0)
                            # list-name at XXX
                            line = re.sub(rf"(.*?) ({escaped_list_name})\s+at\s+(.*)", r"\1 \2@\3", line, count=0)
                            # mailto:XXX at XXX 
                            line = re.sub(r"mailto:(.*?)\s+at\s+(.*)", r"mailto:\1@\2", line, count=0)
                            # <XXX at XXX>
                            line = re.sub(r"<(.*?)\s+at\s+(.*)>", r"<\1@\2>", line, count=0)
                            f.write(line)
                else:
                    print("- Could not find "+tz_path)
    print("- Done")


def concat_mbox(list_name, save_path, start_year, end_year, rm):
    """Concats all mailboxes found in the given directory."""

    print("Merging mailboxes ...")
    out_path = os.path.join(save_path, list_name+".mbox")
    years = range(start_year, end_year+1)
    months = range(1, 12+1)

    with open(out_path, "wb") as out_file:
        for y in years:
            for m in months:
                postfix = str(y)+"-"+str(m).zfill(2)
                mbox_path = os.path.join(save_path, list_name+"_"+postfix+".mbox")
                if os.path.exists(mbox_path):
                    with open(mbox_path, 'rb') as box_file:
                        shutil.copyfileobj(box_file, out_file)
                    if rm:
                        os.remove(mbox_path)
                else:
                    print("- Could not find "+mbox_path)
    print("- Done")


def rename_mbox(list_name, save_path):
    """Renames the mailboxes in the given directory."""

    if list_name.startswith("pgsql"):
        for file in os.listdir(save_path):
            year = file.split(".")[1][0:4]
            month = file.split(".")[1][4:6]
            postfix = year+"-"+month
            
            file_path = os.path.join(save_path, file)
            mbox_path = os.path.join(save_path, list_name+"_"+postfix+".mbox")
            os.rename(file_path, mbox_path)
    else:
        print("Unknown renaming scheme for "+str(list_name))


def main(mbox_archive, list_name, save_path, start_year, end_year, download, rename, convert, concat, rm_pre, rm_post):
    if rm_pre:
        # Clean output directory.
        if os.path.exists(save_path):
            shutil.rmtree(save_path)
        os.makedirs(save_path)

    if download:
        print(mbox_archive)
        download_mbox(mbox_archive, list_name, save_path, start_year, end_year)

    if rename:
        rename_mbox(list_name, save_path)

    if convert:
        convert_mbox(list_name, save_path, start_year, end_year)

    if concat:
        concat_mbox(list_name, save_path, start_year, end_year, rm_post)


if __name__ == "__main__":
    args = arguments()
    main(args.mbox_archive, args.list_name, args.save_path, int(args.start_year), int(args.end_year), 
         args.download, args.rename, args.convert, args.concat, args.rm_pre, args.rm_post)
