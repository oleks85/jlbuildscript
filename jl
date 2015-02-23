#!/bin/bash
RESET_DB_FOLDER=~/development/projects/ATG/reset-db/
MOCKS_WS_FOLDER=~/development/projects/MocksWS/
ATG_PRJ_FOLDER=~/development/projects/ATG/
FRONTEND_CONFIG_FOLDER=~/development/projects/ATG/front-end-config/

JL=jl

# Formatting constants
export BOLD=`tput bold`
export UNDERLINE_ON=`tput smul`
export UNDERLINE_OFF=`tput rmul`
export TEXT_BLACK=`tput setaf 0`
export TEXT_RED=`tput setaf 1`
export TEXT_GREEN=`tput setaf 2`
export TEXT_YELLOW=`tput setaf 3`
export TEXT_BLUE=`tput setaf 4`
export TEXT_MAGENTA=`tput setaf 5`
export TEXT_CYAN=`tput setaf 6`
export TEXT_WHITE=`tput setaf 7`
export BACKGROUND_BLACK=`tput setab 0`
export BACKGROUND_RED=`tput setab 1`
export BACKGROUND_GREEN=`tput setab 2`
export BACKGROUND_YELLOW=`tput setab 3`
export BACKGROUND_BLUE=`tput setab 4`
export BACKGROUND_MAGENTA=`tput setab 5`
export BACKGROUND_CYAN=`tput setab 6`
export BACKGROUND_WHITE=`tput setab 7`
export RESET_FORMATTING=`tput sgr0`
# Wrapper function for Maven's mvn command.
mvn-color(){
	# Filter mvn output using sed
	mvn $@ | sed -e "s/\(\[INFO\]\ \-.*\)/${RESET_FORMATTING}\1/g" \
	-e "s/\(\[INFO\]\ \[.*\)/${RESET_FORMATTING}${BOLD}\1${RESET_FORMATTING}/g" \
	-e "s/\(\[INFO\]\ BUILD SUCCESSFUL\)/${BOLD}${TEXT_GREEN}\1${RESET_FORMATTING}/g" \
	-e "s/\(\[WARNING\].*\)/${BOLD}${TEXT_YELLOW}\1${RESET_FORMATTING}/g" \
	-e "s/\(\[ERROR\].*\)/${BOLD}${TEXT_RED}\1${RESET_FORMATTING}/g" \
	-e "s/Tests run: \([^,]*\), Failures: \([^,]*\), Errors: \([^,]*\), Skipped: \([^,]*\)/${BOLD}${TEXT_GREEN}Tests run: \1${RESET_FORMATTING}, Failures: ${BOLD}${TEXT_RED}\2${RESET_FORMATTING}, Errors: ${BOLD}${TEXT_RED}\3${RESET_FORMATTING}, Skipped: ${BOLD}${TEXT_YELLOW}\4${RESET_FORMATTING}/g"
	# Make sure formatting is reset
	echo -ne ${RESET_FORMATTING}
}

#update project source code 
svn_update() {
  svn update $ATG_PRJ_FOLDER $MOCKS_WS_FOLDER ~/development/projects/ATGAT
  STATUS=$?
  if [ $STATUS -eq 0 ]; then
    echo "Successfull update"
  else 
   echo "SVN update failed"
   return $STATUS
  fi
}

#run sql scripts
update_schema() {
 echo "Start updating database schema ..."
 mvn-color -Pupdate-schema process-resources -f $RESET_DB_FOLDER"pom.xml"
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "Database schema successfully updated"
 else
  echo "There are some errors happed during update database schema"
  return $STATUS
 fi
}

#build project without tests
no_test_build() {
 mvn-color clean install -DskipTests=true -Dtest.environment=dev -f $ATG_PRJ_FOLDER"pom.xml"
 STATUS=$? 
 if [ $STATUS -eq 0 ]; then
  echo "Project successfully builded"
 else
  echo "There are some errors happed during project building."
  return $STATUS
 fi
}

#build project  -DskipTests=true
buildall() {
 echo "Start building project ..."
 mvn-color clean install -Dtest.environment=dev -f $ATG_PRJ_FOLDER"pom.xml"
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "Project successfully builded"
 else
  echo "There are some errors happed during project building."
  return $STATUS
 fi
}

#Recreate a clean localconfig
recreatelocalconfig() {
 echo "Start recreating a localconfigs ..."
 ~/development/projects/ATG/dsm_jec_Website/env/JL_DEV/bin/clear-localconfig.sh 
}

#Recreate database existing schemas, and recreate them
recreateDbSchemas() {
 echo "Start recreating database schemas .."
 echo exit | sqlplus system/manager @$HOME/development/projects/ATG/dsm_jec_Website/env/JL_DEV/recreate-db.sql
}

#Reinitialise the schemas
reinitialiseDbSchemas() {
 echo "Start reinitialising the schemas"
 mvn-color install -Preset-db -Dtest.environment=dev -f $RESET_DB_FOLDER"pom.xml"
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "Reinitialised successfully"
 else
  echo "!!!! something went wrong: reinitialising the schemas"
  return $STATUS
 fi
}

#Reload data
loadData() {
 mvn-color install -Pload-data-ftw -Dtest.environment=dev -f $RESET_DB_FOLDER"pom.xml"
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "Reloaded successfully"
 else
  echo "!!!! something went wrong: load data"
  return $STATUS
 fi
}

#deploy data
deployData() {
 mvn-color clean install -Dtest.environment=dev -f $FRONTEND_CONFIG_FOLDER"pom.xml"
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "Data deployed successfully"
 else
  echo "!!!! something went wrong: deploy data"
  return $STATUS
 fi
}

#deploy mocks
deployMosks() {
 echo "Start deploying mocks ..."
 echo "***"
 echo "***"
 echo "***"
 read -p "*** Please run mocks using moks-start command in separete terminal and press Enter to continue or Ctrl+C to exit..." 
 mvn-color clean install -Pjboss,deploy -f $MOCKS_WS_FOLDER"pom.xml"
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "Mocks successfully deployed"
 else
  echo "There are some errors happed during deploying mocks"
  return $STATUS
 fi
}

#full load data
fullloaddata() {
 echo "***"
 echo "***"
 echo "***"
 read -p "*** Close all runnig jboss (store, mocks, bcc, etc...) and press Enter to continue or Ctrl+C to exit..."
 buildall
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  recreatelocalconfig
 else
  return $STATUS
 fi
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  recreateDbSchemas
 else
  return $STATUS
 fi
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  reinitialiseDbSchemas
 else
  return $STATUS
 fi
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
 loadData
 else
  return $STATUS
 fi

 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  echo "***"
  echo "***"
  echo "***"
  read -p "*** Please start bcc and store in separate terminal window (bcc-start, store-start) and press Enter to continue..."
  deployData
 else
  return $STATUS
 fi
}

updateAndBuild() {
 svn_update
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  update_schema
 else
  return $STATUS
 fi
 STATUS=$?
 if [ $STATUS -eq 0 ]; then
  buildall
 else
  return $STATUS
 fi
}

execute_operation() {
	case "$1" in
	 svn-update)
	  svn_update
	  RETVAL=$?
	  ;;
	 update-schema)
	  update_schema
	  RETVAL=$?
	  ;;
	 build-without-tests)
	  no_test_build
	  RETVAL=$?
	  ;;
	 build-atg)
	  buildall
	  recreatelocalconfig
	  RETVAL=$?
	  ;;
	 full-load-data)
	  fullloaddata
	  RETVAL=$?
	  ;;
	 update-and-build)
	  updateAndBuild
	  RETVAL=$?
	  ;;
	 mocks-deploy)
	  deployMosks
	  RETVAL=$?
	  ;;
	 *)
	  echo $"Usage: ${JL} {svn-update|build-without-tests|update-and-build|update-schema|build-atg|full-load-data|mocks-deploy}"
	  ans=$(zenity --list --text "Please chose operation(s) you want to execute                             " --checklist \
		--column "Pick" --column "operation" --column "Description"\
		TRUE "svn-update" "Execute 'svn update' command on '$ATG_PRJ_FOLDER; $MOCKS_WS_FOLDER' folders" \
		TRUE "update-schema" "Update database schemas" \
		TRUE "build-atg" "Build ATG project" \
		FALSE "build-without-tests" "Buld ATG project and do not invoke jUnit tests"\
		FALSE "mocks-deploy" "Build and deploy mocks" \
		FALSE "full-load-data" "Full load data" \
		--separator=":" --width=600 --height=400);
	  IFS=":" read -ra OP <<< $ans
	  for x in ${OP[@]}; do
	     execute_operation ${x}
	     RETVAL=$?
	     if [ $RETVAL -eq 0 ]; then
		echo "The $x process successfully completed"
		notify-send -i /usr/share/icons/gnome/32x32/emotes/face-cool.png -t 5000 "The '$x' succesfully done"
	     else
		echo "An error happen during the $x process"
		notify-send -i /usr/share/icons/gnome/32x32/emotes/face-surprise.png -t 10000 "The '$x' failed with an error"
		return 1
	     fi
	  done
	  ;;
	esac

	return $RETVAL
}

execute_operation $1

exit $?

