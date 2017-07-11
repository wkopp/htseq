#!/bin/bash
# only deploy builds for a release_<sematic-version>_RC?? tag to testpypi
if [ -z $TRAVIS_TAG ]; then
  echo 'No TRAVIS_TAG, exit'
  exit 0
fi
TAG1=$(echo $TRAVIS_TAG | cut -f1 -d_)
TAG2=$(echo $TRAVIS_TAG | cut -f2 -d_)
TAG3=$(echo $TRAVIS_TAG | cut -f3 -d_)
if [ -z $TAG2 ] || [ -z $TAG3 ]; then
  echo 'No TAG2 or TAG3, exit'
  exit 0;
fi
if [ $TAG1 != 'release' ] || [ $TAG2 != $(cat VERSION) ]; then
  echo 'No release tag or wrong version, exit'
  exit 0;
fi

# do not deploy outside of manylinux1
if [ -z $DOCKER_IMAGE ] && [ $TRAVIS_OS_NAME != 'osx' ]; then
  echo 'Not inside manylinux docker image and not OSX, exit'
  exit 0
fi

# deploy onto pypitest unless you have no RC
if [ ${TAG3:0:2} == 'RC' ]; then
  TWINE_PASSWORD=${TWINE_PASSWORD_TESTPYPI}
  TWINE_REPOSITORY='https://testpypi.python.org/pypi'
  echo 'Deploying to testpypi'
else
  #FIXME
  #TWINE_PASSWORD=${TWINE_PASSWORD_PYPI}
  #TWINE_REPOSITORY='https://pypi.python.org/pypi'
  echo 'Deploying to production pypi'
fi
   
if [ $DOCKER_IMAGE ]; then
  # Wheels are already tested in docker image
  docker run -e TWINE_REPOSITORY="$TWINE_REPOSITORY" -e TWINE_USERNAME="$TWINE_USERNAME" -e TWINE_PASSWORD="$TWINE_PASSWORD" --rm -v $(pwd):/io $DOCKER_IMAGE /io/deploywheels.sh 

elif [ $TRAVIS_OS_NAME == 'osx' ]; then
  # OSX deployment
  echo "Deploying for OSX"
  HTSEQ_VERSION=$(cat VERSION)
  echo "TWINE_REPOSITORY=$TWINE_REPOSITORY"
  echo "TWINE_USERNAME=$TWINE_USERNAME"
  echo "TWINE_PASSWORD=$TWINE_PASSWORD"
  export PATH="$HOME/miniconda/bin:$PATH"
  source $HOME/miniconda/bin/activate
  pip --version
  pip install twine
  if [ $PYTHON_VERSION == '2.7' ]; then
    PYARCH='cp27-cp27m'
  elif [ $PYTHON_VERSION == '3.6' ]; then
    PYARCH='cp36-cp36m'
  else
    echo "Python version not recognized"
    exit 1
  fi

  echo "Contents of wheelhouse:"
  ls wheelhouse
  TWINE_WHEEL=$(ls wheelhouse/HTSeq-${HTSEQ_VERSION}-${PYARCH}*.whl)
  echo "TWINE_WHEEL=$TWINE_WHEEL"
  twine register -r "${TWINE_REPOSITORY}" -u "${TWINE_USERNAME}" -p "${TWINE_PASSWORD}" "${TWINE_WHEEL}"
  if [ $? != 0 ]; then
      exit 1
  fi
  twine upload  -r "${TWINE_REPOSITORY}" -u "${TWINE_USERNAME}" -p "${TWINE_PASSWORD}" "${TWINE_WHEEL}"
  if [ $? != 0 ]; then
      exit 1
  fi
else
  echo "No DOCKER_IMAGE and not OSX, we should not be here!"
  exit 1
fi