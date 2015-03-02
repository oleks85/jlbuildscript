#!/bin/bash
RESET_DB_FOLDER=~/development/projects/ATG/reset-db/
MOCKS_WS_FOLDER=~/development/projects/MocksWS/
ATG_PRJ_FOLDER=~/development/projects/ATG/
FRONTEND_CONFIG_FOLDER=~/development/projects/ATG/front-end-config/

#Resolve the directory where the script is placed
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#include sources
. ${SCRIPT_DIR}/mvn-color
. ${SCRIPT_DIR}/svn-color
. ${SCRIPT_DIR}/start-stop

JL=jl

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
 startMocks
 sleep 2
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
 stopBcc
 stopStore
 stopMocks
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
  startMocks
  startStore
  startBcc
  sleep 2
  deployData
  stopBcc
  stopStore
  stopMocks
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
	 mocks-start)
	  startMocks
	  ;;
	 store-start)
	  startStore
	  ;;
   	 bcc-start)
	  startBcc
	  ;;
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
		FALSE "mocks-start" "Start mocks server" \
		FALSE "store-start" "Start store server" \
		FALSE "bcc-start" "Start BCC server" \
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

