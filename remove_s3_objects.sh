#!/bin/bash
function verify_logged_in() {
	if aws sts get-caller-identity > /dev/null 2>&1; then
		return
	else 
		echo "Could not verify login"
		echo "Make sure you're logged in to aws-cli v2"
		echo "Exiting"
		exit 1
	fi
}
function print_menu_set_choice() {
	echo
	echo "=== S3 Object Deletion Main Menu ==="
	echo "[1] Delete all objects in a bucket"
	echo "[2] Delete individual objects in a bucket"
	read -p "Select option # or 'q' to quit: " choice
}
function get_print_buckets_set_selection () {
	buckets=$(aws s3api list-buckets --query Buckets[].Name --output text)
	if [ "$buckets" = "None" ]; then
		echo "No buckets found"
		echo "Exiting"
		exit 0
	fi
	echo
	echo "=== S3 Object Deletion Bucket Menu ==="
	i=1
	for bucket in $buckets; do
		echo [$i]  $bucket
		i=$[$i + 1]
	done
	unset i
	read -p "Select bucket # or 'q' to quit to main menu: " selection
}
function print_objects_set_obj_selection () {
	echo
	echo "=== S3 Object Deletion Object Menu ==="
	i=1
	for object in $objects; do
		echo [$i]  $object
		i=$[$i + 1]
	done
	unset i
	read -p "Select object # to delete or 'q' to quit to bucket menu: " obj_selection
}
function valid_bucket () {
	if [[ $selection =~ ^[1-9]{1}[0-9]{0,}$ ]] && [ $selection -le $array_size ] && [ $selection -ge 1 ]; then
		return 0
	fi
	return 1
}
function valid_object () {
	if [[ $obj_selection =~ ^[1-9]{1}[0-9]{0,}$ ]] && [ $obj_selection -le $array_size ] && [ $obj_selection -ge 1 ]; then
		return 0
	fi
	return 1
}
function check_input () {
	if [ $bad_input_count -ge 3 ]; then
		echo "Bad input threshold reached"
		echo "Exiting"
		exit 1
	fi
}
bad_input_count=0
while :; do
	verify_logged_in
	check_input
	print_menu_set_choice
	if ! [[ $choice =~ ^[12qQ]{1}$  ]] ; then
		bad_input_count=$[ $bad_input_count + 1 ]
		echo "Unknown command"
		continue
	fi
	if [ $choice = 'q' ] || [ $choice = 'Q' ]; then
		echo "Exiting"
		exit 0
	elif [ $choice -eq 1 ]; then
		bad_input_count=0
		while :; do
			check_input
			get_print_buckets_set_selection
			if [ $selection = 'q' ] || [ $selection = 'Q' ]; then
				echo "Returning to main menu"
				break
			fi
			bucket_array=($buckets)
			array_size=${#bucket_array[@]}
			if valid_bucket; then
				bad_input_count=0
				selected_bucket=${bucket_array[selection - 1]}
				objects=$(aws s3api list-objects --bucket $selected_bucket --query Contents[].Key --output text)
				if [ "$objects" = "None" ]; then
					echo "Bucket is empty"
					echo "Returning to bucket menu"
					continue
				fi
				echo  "The following objects will be deleted: "
				for object in $objects; do
					echo $object
				done
				read -p "Confirm delete all objects in $selected_bucket? [Y/N] " confirmation
				case $confirmation in
					Y|y)
						echo -e "Deleting..."
						;;
					N|n)
						echo -e "Deletion cancelled"
						echo "Returning to bucket menu"
						continue
						;;
					*)
						bad_input_count=$[ $bad_input_count + 1 ]
						echo -e "Unknown command"
						continue
						;;
				esac
				# too many api calls, can delete all in one go with JSON file containing keys
				# implement this later!
				for object in $objects; do
					aws s3api delete-object --bucket $selected_bucket --key $object
				done
				echo "Deleted all objects in $selected_bucket"
			else
				echo "Unknown command"
				bad_input_count=$[ bad_input_count + 1 ]
			fi
		done
	elif [ $choice -eq 2 ]; then
		bad_input_count=0
		while :; do
			check_input
			get_print_buckets_set_selection
			if [ $selection = 'q' ] || [ $selection = 'Q' ]; then
				echo "Returning to main menu"
				break
			fi
			bucket_array=($buckets)
			array_size=${#bucket_array[@]}
			if valid_bucket; then
				bad_input_count=0
				while :; do
					check_input
					selected_bucket=${bucket_array[selection - 1]}
					objects=$(aws s3api list-objects --bucket $selected_bucket --query Contents[].Key --output text)
					if [ "$objects" = "None" ]; then
						echo "Bucket is empty"
						echo "Returning to bucket menu"
						break
					fi
					print_objects_set_obj_selection
					if [ $obj_selection = 'Q' ] || [ $obj_selection = 'q' ]; then
						echo "Returning to bucket menu"
						break;
					fi
					object_array=($objects)
					array_size=${#object_array[@]}
					if valid_object; then
						bad_input_count=0
						selected_object=${object_array[$obj_selection - 1]}
						read -p "Confirm delete ${selected_object}? [Y/N] " confirmation
						case $confirmation in
						Y|y)
							echo -e "Deleting..."
							;;
						N|n)
							echo -e "Deletion cancelled"
							echo "Returning to object menu"
							continue
							;;
						*)
							bad_input_count=$[ $bad_input_count + 1 ]
							echo -e "Unknown command"
							continue
							;;
						esac
						aws s3api delete-object --bucket $selected_bucket --key $selected_object
						echo "Deleted $selected_object in $selected_bucket"
					else
						bad_input_count=$[ $bad_input_count + 1 ]
						echo "Unknown command"
						continue
					fi
				done
			else 
				bad_input_count=$[ $bad_input_count + 1 ]
				echo "Unknown command"
			fi
		done
	fi
done
