#!/bin/bash
cd /home/sarria/scripts/youtube/
(
exec 4>&1
exec > verbose.log 2>&1
#lock
flock -xn 200 || exit 1
#Mount Testing
echo "Testing WebDav mount" >&4
if [ ! -d /home/sarria/nextcloud/Music ]; then
 echo "WebDav is not mounted - Attempting to mount" >&4
 mount ~/nextcloud
 if [ ! -d /home/sarria/nextcloud/Music ]; then
 	echo "Mounting failed, closing." >&4
 	exit 1
 else echo "Mounting successful" >&4
 fi
fi
echo "WebDav Mounted, proceeding" >&4

#Youtube-DL
function download_shit() {
youtube-dl -i --no-continue $3 --download-archive "archive/$1" --output "temp/$1/$2/%(uploader)s/%(title)s.%(ext)s" -f bestaudio $4
filecount="$(find temp/$1/$2/ -maxdepth 1 -type f | wc -l)"
}
for fullusr in users/*
do
	user=$(basename $fullusr)
	#Read each line of user config as new channel
	runcount=0
	while read chan; do
		runcount=$((runcount+1))
		limiter="--playlist-end 5"
		echo "$user: Scanning channel $runcount ..." >&4
		download_shit "$user" "$runcount" "$limiter" "$chan"
		#Checks if we should do a full scan
		if [ $filecount = 0 ]; then
			echo "$user: No new songs found on $chan" >&4
			#break
		elif [ $filecount = 5 ]; then
			echo "$user: Starting full scan" >&4
			limiter="--playlist-start 6"
			download_shit "$user" "$runcount" "$limiter" "$chan"
			echo "$user: Found $filecount new songs" >&4
		elif [ $filecount = 1 ]; then
			echo "$user: $filecount new song downloaded" >&4
		else
			echo "$user: $filecount new songs downloaded" >&4
		fi
	done <$fullusr
	if [ $(find temp/$user -type f | wc -l) -gt 0 ]; then
		echo "$user: Starting conversion and transfer" >&4
		#Convert webms to oggs
		find temp/$user -iname "*.webm" -exec sh -c 'ffmpeg -i "$1" -f ogg -c copy "${1%.*}".ogg' _ {} \;
		if [ "$?" = "0" ]; then
			echo "$user: .webm files successfully converted" >&4
			echo "$user: deleting old files" >&4
			find . -name "*.webm" -type f -delete
		else
			echo "$user: FFmpeg conversion unsuccessful, closing" >&4
			exit 1
		fi

		#Move the files to owncloud and delete temp storage file
		echo "$user: Transferring to Nextcloud" >&4
		rsync -avr temp/$user/*/ /home/sarria/nextcloud/Music/$user/
		if [ "$?" = "0" ]; then
			echo "$user: File transfer complete" >&4
			echo "$user: Deleting temporary files" >&4
			rm -rv temp/$user/ 1>>verbose.log
		else
			echo "$user: File transfer failed, closing" >&4
			exit 1
		fi
	fi
done
echo "Script Finished" >&4
exit
) 200> lock_sync.lck
