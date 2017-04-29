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
	dialog --clear  --backtitle "Docker Command Center" --title "[ Image Console ]" --menu "${MENUNOTE}Choose a command:" 25 55 10 List "Displays a list of images" Return "Return to main menu" Exit "Exit to the shell" 2>"${INPUT}"
	menuitem=$(<"${INPUT}")
	case $menuitem in
		List) listimages;;
		Return) mainmenu;;
		Exit) break;;
		*) break;
	esac	
}
function containermenu(){
        if [ 1$VMNAME = "1" ]
         then
		MENUNOTE="No container is currently selected.\nUse List to select a container to manage.\n"
	 else
		getContainerState ;
		MENUNOTE="Selected container: '${VMNAME}'.\nContainer is ${STATE}.\n"
        fi

	dialog --clear  --backtitle "Docker Command Center" --title "[ Container Console ]" --menu "${MENUNOTE}Choose a command:" 25 55 10 List "Displays a list of containers" Start "Start a Container" Kill "Stop a Container" Pause "Pause a Container" Unpause "Unpause a Container" Return "Return to main menu" Exit "Exit to the shell" 2>"${INPUT}"
	
	menuitem=$(<"${INPUT}")

        case $menuitem in
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
