currentBuild.displayName = "Wildfly_20.0:#"+currentBuild.number

pipeline{
    agent any

    environment{
        DOCKER_TAG = getDockerTag()
        VAR_REGISTRY = 'registry.metroscales.io'
        VAR_VERSION = '20.0'
    }
    stages{
        stage("Docker build Image"){
            steps{
                sh "docker build --build-arg REGISTRY=${VAR_REGISTRY} . -t ${VAR_REGISTRY}/asm/wildfly-dev:${VAR_VERSION}.${env.BUILD_NUMBER}"
            }
        }

        stage("Retag DEV Image"){
            steps{
                sh "docker tag ${VAR_REGISTRY}/asm/wildfly-dev:${VAR_VERSION}.${env.BUILD_NUMBER} ${VAR_REGISTRY}/asm/wildfly-dev:${VAR_VERSION}"
            }
        }

        stage("Login to docker registry"){
            steps{
                withCredentials([string(credentialsId: 'registry_pwd', variable: 'VAR_PASSWORD')]) {
                    sh "docker login ${VAR_REGISTRY} --username 'robot\$robot_asm' --password ${VAR_PASSWORD}"
                }
            }
        }
        
        stage("Docker push Image to registry.metroscales.io"){
            steps{
                sh "docker push ${VAR_REGISTRY}/asm/wildfly-dev:${VAR_VERSION}.${env.BUILD_NUMBER}"
                sh "docker push ${VAR_REGISTRY}/asm/wildfly-dev:${VAR_VERSION}"
            }
        }

    }
}

def getDockerTag(){
    def tag = sh script: 'git rev-parse HEAD', returnStdout: true
    return tag
}
