#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/snap/bin
echo $PATH
cd ${0%/*}
exec 200> lock_sync.lck
exec 4>&1
exec > verbose.log 2>&1
#lock
flock -xn 200 || { echo lock already held >&4 ; exit 1 ; }
#Mount Testing
echo "Testing WebDav mount" >&4
if [ ! -d /home/sarria/nextcloud/Music ]; then
 echo "WebDav is not mounted - Attempting to mount" >&4
 mount ~/nextcloud 200>/dev/null
 if [ ! -d /home/sarria/nextcloud/Music ]; then
 	echo "Mounting failed, closing." >&4
 	exit 1
 else echo "Mounting successful" >&4
 fi
fi
echo "WebDav Mounted, proceeding" >&4

#Youtube-DL
function download_shit() {
youtube-dl -i --no-continue $3 --download-archive "archive/$1" --output "temp/$1/$2/$name/%(title)s.%(ext)s" -f bestaudio $4
filecount="$(find temp/$1/$2/ -type f | wc -l)"
}
for fullusr in users/*
do
	user=$(basename $fullusr)
	#Read each line of user config as new channel
	runcount=0
	while read line; do
		set -- $line #sets each space separated word as a $1+ argument
		chan=$1
		name=$2
		if [ -z $name ]; then echo "No name on channel $chan of $user, skipping $line" >&4; continue; fi
		runcount=$((runcount+1))
		limiter="--playlist-end 5"
		echo "$user: Scanning channel $runcount ..." >&4
		download_shit "$user" "$runcount" "$limiter" "$chan"
		#Checks if we should do a full scan
		if [ $filecount = 0 ]; then
			echo "$user: No new songs found on $name" >&4
		elif [ $filecount = 5 ]; then
			echo "$user: Starting full scan on $name" >&4
			limiter="--playlist-start 6"
			download_shit "$user" "$runcount" "$limiter" "$chan"
			echo "$user: Found $filecount new songs on $name" >&4
		elif [ $filecount = 1 ]; then
			echo "$user: $filecount new song downloaded on $name" >&4
		else
			echo "$user: $filecount new songs downloaded on $name" >&4
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
echo "############################################################" >&4
done
echo "Script Finished" >&4

