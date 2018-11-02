#!/usr/bin/env bash

#Get tool
wget http://jenkins/jnlpJars/jenkins-cli.jar
#Prepare workspace
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin create-job HelloWorld < init.xml
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin build HelloWorld

#Configure docker
cp ./Dockerfile /var/lib/jenkins/workspace/HelloWorld

#Configure Jenkins+Docker
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin update-job HelloWorld < config.xml
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin build HelloWorld
