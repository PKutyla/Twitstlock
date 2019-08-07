#!/bin/bash
GIT_USER_NAME=$1
GIT_PASSWORD=$2
VERSION=$3
PUSH=$4
profile=peter.kutyla
GRN=Twistlock
ecr_image_name=helloworldtest
if [[ -z $GIT_USER_NAME || -z $GIT_PASSWORD ]]; then
    echo "Usage: ./build_image.sh <GIT_USER_NAME> <GIT_PASSWORD> <IMAGE_VERSION> <PUSH>"
    echo -e "\t\"PUSH\" must be passed as 'y' to build the docker image and push it to the docker repository"
    exit
fi
read -p "Type \"$GRN\" to confirm that you are about to build and push a new version of a docker to ECR: " grn
if [[ $grn != $GRN ]]; then
    echo "Invalid name of git repo. Will not commence the build and push."
    exit 1
fi
if [[ -z $profile ]]; then
    if [[ -z $AWS_PROFILE ]]; then
        echo "Set \"AWS_PROFILE\" as an environmental variable to proceed"
        exit
    fi
    profile=$AWS_PROFILE
    PROFILE="--profile $profile"
    account=$(aws sts get-caller-identity $PROFILE | jq '.Account' | sed 's/"//g')
fi
 PROFILE="--profile $profile"

account=417302553802

if [[ -z $VERSION ]]; then
    echo "Please provide a version with which to tag $ecr_image_name"
    exit 1
else
    VERSION_EXISTS=$(for i in $(aws ecr describe-images --repository-name $ecr_image_name --registry-id $account | jq .imageDetails[].imageTags -c); do if [[ $i != "null" ]]; then echo $i | jq .[] | sed 's/"//g'; fi; done | grep $VERSION)
    echo $VERSION_EXISTS
    if [[ ! -z $VERSION_EXISTS && $VERSION != "latest" ]]; then
        read -p "You are about to overwrite a version of this docker image in ECR. Type the version again to do so: " grn
        if [[ $grn != $VERSION ]]; then
            echo "Will not build this image as $grn does not match \"$VERSION\""
            exit 1
        fi
    fi
fi

docker build --build-arg USER_NAME=$GIT_USER_NAME --build-arg PASSWORD=$GIT_PASSWORD -t $ecr_image_name:$VERSION .
docker tag $ecr_image_name:$VERSION $account.dkr.ecr.us-east-1.amazonaws.com/$ecr_image_name:$VERSION
eval $(aws ecr get-login --registry-ids $account --no-include-email --region us-east-1 $PROFILE)
out=$(aws ecr describe-repositories --registry-id $account --repository-names ${ecr_image_name%:*} $PROFILE)
if [[ $out == '' ]]; then
    echo "Doesn't exist!"
    read -p "You are about to create a new repository in $account ecr. Type \"$GRN\" to continue: " grn
    if [[ $grn == $GRN ]]; then
        aws ecr create-repository --repository-name $repo_name $PROFILE
    else
        echo "Will not create the new repository as $grn does not match the git repo name."
        exit 1
    fi
fi
if [[ ! -z $PUSH && $PUSH == 'y' ]]; then
    docker push $account.dkr.ecr.us-east-1.amazonaws.com/$ecr_image_name:$VERSION
else
    echo "PUSH was either not passed or was not 'y'."
fi
