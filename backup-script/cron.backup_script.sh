#!/bin/bash

### This script will create backups for containerized
### GitLab and TeamCity servers, create a log file,
### removed old backups and create a full ZIP archive
### for subsequent sending to the storage (Yandex Disk).

YD_BACKUP_DST=/root/yadisk_backups
ENTYRE_BACKUP_PATH=$(find "$YD_BACKUP_DST" -maxdepth 1 -name "*.zip" -type f)

COMPOSE_FILE=/root/docker/docker-compose.yml

ANDROID_SOURCE_IP=
ANDROID_BUILDS_PATH=/opt/android-builds

SIRIUS_BACKUP_SRC=/root/gitlab-socialsirius
SIRIUS_BACKUP_DST=/root/yadisk_backups/gitlab-socialsirius
SIRIUS_URL=""

ML_BACKUP_SRC=/root/gitlab-ml
ML_BACKUP_DST=/root/yadisk_backups/gitlab-ml
ML_URL=""

TC_BACKUP_SRC=/root/teamcity_server
TC_BACKUP_DST=/root/yadisk_backups/teamcity_server
TC_URL=""

LOG_PATH=/var/log/cron-backup.log
TIMESTAMP=$(date "+%F %T")

PYTHON_SCRIPT=""
YA_LOGIN=""
YA_PASSWD=""

BG_BLUE='\033[44m'
GREEN='\033[32;1m'
YELLOW_BOLD=$(tput setaf 3 bold)
RED_BOLD=$(tput setaf 1 bold)
NO_CLR=$(tput sgr0)


function get_url_status_code {
  URL_STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$1")
}


function check_container_state {
  CONTAINER_STATUS=$(docker container inspect -f '{{.State.Health.Status}}' "$1")
}


function write_log {
  echo -e "$GREEN
$1:
  Container $1 is available
  URL $2 is available
  Backup created at: $TIMESTAMP
  Backup destination path: $3
  Backup size: $(du -hs "$LATEST_CREATED_BACKUP" | awk '{print $1}')" >> "$LOG_PATH"
}


function gitlab_backup {

  # GitLab backup function
  # $1 - gitlab container name e.g. gitlab-socialsirius or gitlab-ml
  # $2 - gitlab service URL
  # $3 - gitlab backup destination path e.g. *_BACKUP_DST. See variables at the beginning of the script
  # $4 - gitlab source backup path e.g. *_BACKUP_SRC. See variables at the beginning of the script
  # Env vars CONTAINER_STATUS and URL_STATUS_CODE are defined by funtions

  check_container_state "$1"
  get_url_status_code "$2"
  if [[ "$CONTAINER_STATUS" == "healthy" && "$URL_STATUS_CODE" == "200" ]]; then
    if [ -d "$3" ] || mkdir -p "$3"; then
      echo -e "${YELLOW_BOLD}\nStarting $1 backup at: $TIMESTAMP $NO_CLR\n" >> "$LOG_PATH"
      if docker container exec -t "$1" gitlab-backup create >> "$LOG_PATH"; then
        echo -e "${YELLOW_BOLD}Finished $1 backup at: $TIMESTAMP $NO_CLR\n" >> "$LOG_PATH"
        LATEST_CREATED_BACKUP=$(find "$4/backups" -type f -printf "%T@ %p\n" | sort -n | tail -1 | awk '{print $2}')
        cp -rp "$LATEST_CREATED_BACKUP" "$3"

        # Print info to log file
        write_log "$1" "$2" "$3"

        # Copy GitLab config
        if cp -rp "$4/config" "$3"; then
          echo -e "
  Config path: $3/config
  Config size: $(du -hs "$3/config" | awk '{print $1}') $NO_CLR" >> "$LOG_PATH"
        fi
      fi
    fi
  else
    if [ "$CONTAINER_STATUS" == "healthy" ]; then
      echo -e "$RED_BOLD
ERROR:$1: Service are unavailable!
  Container $1 running state is: ${GREEN}$CONTAINER_STATUS
$RED_BOLD  Сheck nginx config and daemon or network availability!
  URL $SIRIUS_URL status:${GREEN} $URL_STATUS_CODE $NO_CLR" >> "$LOG_PATH"

    else
      echo -e "$RED_BOLD
ERROR:$1: Container $1 are unavailable!
  Exited with status:${GREEN} $(docker container inspect $1 --format='{{.State.ExitCode}}') $NO_CLR" >> "$LOG_PATH"
    fi
  fi
}

function rm_old_backups {

# Manage Gitlab backups script.
# This function will delete oldest backups in Gitlab backup-dirs if files count more than 3.
# It takes "socialsirius" or/and "ml" arguments like existing data directories names
# defined below in the body of the function.

  local FILES_PATH=$1
  if [ -d "$FILES_PATH" ]; then
    local FILES_COUNT DELETE_COUNT MESSAGE
    FILES_COUNT=$(find "$FILES_PATH" -maxdepth 1 -type f | wc -l)

    if [ "$FILES_COUNT" -gt "3" ]; then
      DELETE_COUNT=$(( FILES_COUNT-3 ))

      if [ "$DELETE_COUNT" -eq "1" ]; then
        MESSAGE="file"
      else
        MESSAGE="files"
      fi
      echo -ne "$GREEN
$2:$NO_CLR
  There are $FILES_COUNT $MESSAGE in $FILES_PATH directory
  $DELETE_COUNT oldest $MESSAGE will be deleted\n" >> "$LOG_PATH"

      while [ "$FILES_COUNT" -gt "3" ]; do
        rm -f "$(find "$FILES_PATH" -maxdepth 1 -type f -printf "%T@ %p\n" | sort -n | awk '{print $2}' | sed -n 1p)"
        FILES_COUNT=$(find "$FILES_PATH" -maxdepth 1 -type f | wc -l)
      done
    fi
  else
    echo -e "$RED_BOLD
Gitlab-$1:ERROR: Can not delete old backups. Directory $FILES_PATH doesn't exist!$NO_CLR" >> "$LOG_PATH"
  fi
}


# START

# Remove all files in destination backup path
if [ -d "$YD_BACKUP_DST" ] || mkdir -p "$YD_BACKUP_DST"; then
  echo "" >> "$LOG_PATH"
  echo -e "${BG_BLUE}Start removing old backups from $YD_BACKUP_DST at $TIMESTAMP $NO_CLR" >> "$LOG_PATH"
  find "$YD_BACKUP_DST" -delete

### Start socialsirius backup
  gitlab_backup "gitlab-socialsirius" "$SIRIUS_URL" "$SIRIUS_BACKUP_DST" "$SIRIUS_BACKUP_SRC"

### Start ml backup
  gitlab_backup "gitlab-ml" "$ML_URL" "$ML_BACKUP_DST" "$ML_BACKUP_SRC"


### Download Android builds via SSH
  if timeout 3 bash -c "</dev/tcp/$ANDROID_SOURCE_IP/22"; then
    scp -rq root@$ANDROID_SOURCE_IP:$ANDROID_BUILDS_PATH "$YD_BACKUP_DST"
    echo -e "$GREEN
Android-builds:
  Directory copied via SSH at: $TIMESTAMP
  Path: $YD_BACKUP_DST
  Size: $(du -hs $YD_BACKUP_DST/android-builds | awk '{print $1}')$NO_CLR\n" >> "$LOG_PATH"
  fi

### TeamCity backup
  if [ -d "$TC_BACKUP_DST" ] || mkdir -p "$TC_BACKUP_DST"; then
    TC_CONTAINER_STATUS=$(docker container inspect -f '{{.State.Status}}' teamcity)
    get_url_status_code "$TC_URL"
    if [[ "$TC_CONTAINER_STATUS" == "running" && "$URL_STATUS_CODE" == "200" ]]; then
      if docker compose -f "$COMPOSE_FILE" stop teamcity > /dev/null 2>&1; then
        echo -e "${YELLOW_BOLD}Teamcity container stopped, ready for backup\nStarting teamcity backup at $TIMESTAMP $NO_CLR" >> "$LOG_PATH"
        if docker compose -f "$COMPOSE_FILE" run --rm teamcity /opt/teamcity/bin/maintainDB.sh backup &>> "$LOG_PATH"; then
          echo "${YELLOW_BOLD}Finished teamcity backup at: $TIMESTAMP $NO_CLR" >> "$LOG_PATH"

          LATEST_CREATED_BACKUP=$(find $TC_BACKUP_SRC/backup -type f -printf "%T@ %p\n" | sort -n | tail -1 | awk '{print $2}')
          cp -rp "$LATEST_CREATED_BACKUP" "$TC_BACKUP_DST"
          write_log "Teamcity" "$TC_URL" "$TC_BACKUP_DST"
        fi

        if docker compose -f "$COMPOSE_FILE" start teamcity > /dev/null 2>&1; then
          echo -e "${YELLOW_BOLD}  Teamcity container started\n $NO_CLR" >> "$LOG_PATH"
        fi
      else
        echo "ERROR STOPPING CONTAINER TEAMCITY" >> "$LOG_PATH"
      fi
    else
      echo "ERROR CHECK TEAMCITY" >> "$LOG_PATH"
    fi
  fi
  rm_old_backups "$SIRIUS_BACKUP_SRC/backups" "gitlab-socialsirius"
  rm_old_backups "$ML_BACKUP_SRC/backups" "gitlab-ml"
  rm_old_backups "$TC_BACKUP_SRC/backup" "teamcity"

### Create an entire backup file
  if cd "$YD_BACKUP_DST" && zip -r $(date "+all.bak-%F.zip") . &>> "$LOG_PATH"; then
    echo -e "$GREEN
Entyre backup created at $TIMESTAMP:
  Path: $ENTYRE_BACKUP_PATH
  Size: $(du -hs $ENTYRE_BACKUP_PATH | awk '{print $1}')\n $NO_CLR" >> "$LOG_PATH"
  fi
### Run python script
#    if python3 "$PYTHON_SCRIPT" --login="$YA_LOGIN" --password="$YA_PASSWD" --dir="$YD_BACKUP_DST" &>> "$LOG_PATH"; then
#      echo -e "${YELLOW_BOLD}Entire backup saved to Yandex disk at $TIMESTAMP $NO_CLR" >> "$LOG_PATH"
#    fi
#  fi
fi
