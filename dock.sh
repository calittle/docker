#!/bin/bash
#
# Simple Docker menu control using dialog
#

INPUT=/tmp/menu.sh.$$
STATE=
VMNAME=
OUTPUT=/tmp/output.sh.$$
OUTPUT1=/tmp/output1.sh.$$

trap "rm $OUTPUT1; rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

function killvm(){
        if [ $STATE != "running" ]
          then
                dialog --title "Warning" --msgbox "${VMNAME} is not running; cannot stop." 5 55
          else
                dialog --title "Confirm" --yesno "Really stop $VMNAME?" 5 55
                if [ $? = 0 ]
                  then
                        dialog --title "Response" --infobox "${VMNAME} is stopping." 5 55
			docker container stop $VMNAME
                fi
        fi
}
function resetvm(){
        if [ $STATE != "running" ]
          then
                dialog --title "Warning" --msgbox "${VMNAME} is not running; cannot reset." 5 55
          else
                dialog --title "Confirm" --yesno "Really reset $VMNAME?" 5 55
                if [ $? = 0 ]
                  then
                        dialog --title "Response" --infobox "${VMNAME} is restarting." 5 55
                        VBoxManage controlvm $VMNAME reset
                fi
        fi
}
function startvm(){
        if [ $STATE = "running" ]
          then
                dialog --title "Warning" --msgbox "${VMNAME} is running; cannot start." 5 55
          else
	 	dialog --title "Response" --infobox "${VMNAME} is starting." 5 55
                docker start $VMNAME
        fi
}
function unsleepvm(){
        if [ $STATE != "paused" ]
          then
                dialog --title "Warning" --msgbox "${VMNAME} is not paused; cannot pause." 5 55
          else
                        dialog --title "Response" --infobox "${VMNAME} is unpausing." 5 55
                        docker unpause $VMNAME
        fi
}
function sleepvm(){
        if [ $STATE != "running" ]
          then
                dialog --title "Warning" --msgbox "${VMNAME} is not running; cannot pause." 5 55
          else
                dialog --title "Confirm" --yesno "Really pause $VMNAME?" 5 55
                if [ $? = 0 ]
                  then
                        dialog --title "Response" --infobox "${VMNAME} is pausing." 5 55
                	docker pause $VMNAME
		fi
        fi
}
function mainmenu(){
	
	dialog --clear --backtitle "Docker Command Center" --title "[ Docker Control Center ]" --menu "Select a management area:" 25 55 10 Container "Container" Image "Image" Exit "Exit" 2>"${INPUT}"
	menuitem=$(<"${INPUT}")
	case $menuitem in
		Container) containermenu;;
		Image) imagemenu;;
		Exit) break;;
		*) break;;
	esac
		
}
function getContainerState(){
	if [ $VMNAME != "" ]
         then 
	  STATE=$(docker  inspect --format='{{.State.Status}}' $VMNAME)
	fi
}
function startcontainer(){
	if [ 1$IMAGENAME = "1" ]; then
		dialog --backtitle "Docker command Center" --title "Response" --msgbox "You need to pick an image first." 5 75
		imagemenu
	fi
	RUN_CMD=""
	dialog --backtitle "Docker Command Center" --title "Start Container Options" --checklist "Choose container options:\nYou may be able to select invalid combinations.\nChoose wisely!" 20 70 5 1 Interactive on 2 Detached off 3 Psuedo-TTY on 4 "Add more options" off 2>"${INPUT}"
	menuitem=$(<"${INPUT}")
	for item in $menuitem 
	do
		case $item in        	
			1) RUN_CMD+="i" ;;
			2) RUN_CMD+="d" ;;
			3) RUN_CMD+="t" ;;
			4) dialog --inputbox "Enter your run params:" 5 55 $RUN_CMD 2>"${INPUT}"; RUN_CMD=$(<"${INPUT}") ;;
		esac
	done	
		echo Starting container. Use exit to return.
		echo docker run -${RUN_CMD} $IMAGENAME
		docker run -${RUN_CMD} $IMAGENAME
}
function listimages(){
	docker images --format '{{.ID}} "{{.Repository}}:{{.Tag}}"' > $OUTPUT
	dialog --clear --backtitle "Docker Command Center" --title "[ List Images ]" --menu "Select an Image to control" 25 75 10 $(<"${OUTPUT}") 2>"${INPUT}"
        IMAGENAME=$(<"${INPUT}")
	imagemenu;
}
function imagemenu(){
	if [ 1$IMAGENAME = "1" ]
	 then
		MENUNOTE="No image is currently selected.\nUse List to select an image to manage.\n"
	else
		MENUNOTE="Selected image:\n ID:${IMAGENAME}\n Tags:$(docker image inspect ${IMAGENAME} --format {{.RepoTags}})\n\n"
	fi
	dialog --clear  --backtitle "Docker Command Center" --title "[ Image Console ]" --menu "${MENUNOTE}Choose a command:" 25 55 10 Start "Start a container from an image" List "Displays a list of images" Return "Return to main menu" Exit "Exit to the shell" 2>"${INPUT}"
	menuitem=$(<"${INPUT}")
	case $menuitem in
		List) listimages;;
		Start) startcontainer;;
		Return) mainmenu;;
		Exit) break;;
		*) break;
	esac	
}
function attachvm(){
	if [ 1$VMNAME = "1" ]
	  then
		containermenu;
	else
		dialog --title "Confirm" --yesno "Use 'exit' to return to Console. Ready?" 5 55
                if [ $? = 0 ]
                  then
                	# attach or exec? 
			# To use attach we need need to determine if container was started with a shell. 
			# exec is easier.
			docker exec -it ${VMNAME} bash
		fi	
	fi
}
function containermenu(){
        if [ 1$VMNAME = "1" ]
         then
		MENUNOTE="No container is currently selected.\nUse List to select a container to manage.\n"
		listvm
	 else
		getContainerState ;
		MENUNOTE="Selected container: '${VMNAME}'.\nContainer is ${STATE}.\n"
        fi

	dialog --clear  --backtitle "Docker Command Center" --title "[ Container Console ]" --menu "${MENUNOTE}Choose a command:" 25 55 10 Attach "Attach a shell to a running container." List "Displays a list of containers" Start "Start a Container" Kill "Stop a Container" Pause "Pause a Container" Unpause "Unpause a Container" Return "Return to main menu" Exit "Exit to the shell" 2>"${INPUT}"
	
	menuitem=$(<"${INPUT}")
        case $menuitem in 
	    Attach) attachvm;;
	    List) listvm;;
            Start) startvm;;
            Kill) killvm;;
            Reset) resetvm;;
            Pause) sleepvm;;
	    Unpause) unsleepvm;;
	    Return) mainmenu;;
            Exit) break;;
            *) break;;
        esac
}
function listvm(){
        docker ps -f "status=running" --format "{{.ID}} \"{{.Names}}-RUNNING\"" > $OUTPUT
	docker ps -f "status=paused" --format "{{.ID}} \"{{.Names}}-PAUSED\"" >> $OUTPUT
	docker ps -f "status=exited" --format "{{.ID}} \"{{.Names}}-EXITED\"" >> $OUTPUT
	dialog --clear --backtitle "Docker Command Menu" --title "[ Container Control Panel: List Containers ]" --menu "Select a Container to control" 25 75 10 $(<"${OUTPUT}") 2>"${INPUT}"
        VMNAME=$(<"${INPUT}")
	containermenu;
}

while true
do
        mainmenu;
done

# if temp files found, delete em
[ -f $OUTPUT1 ] && rm $OUTPUT1
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
