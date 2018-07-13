# macOS 10.12 Sierra

macOS 10.12 nodes can be initialised with the Shippable agent to run runSh builds. Some of the pre-requisites for installing it are listed below. After installing the pre-requisites, please read about [how to add the node using Shippable UI](http://docs.shippable.com/platform/tutorial/runtime/custom-nodes/). We do not support auto initialisation for macOS at this time. Only manual scripts are supported.

Please do **not** run the script as sudo. Instead, input the password if the script prompts at the time of running it.

## Prerequisites
- [git](https://git-scm.com/download/mac) (latest)
- [Node.js](https://nodejs.org/en/download/) (v8.11.3)
- [Docker](https://docs.docker.com/docker-for-mac/install/) (v17.x.x)

  If you need Docker login during builds, disable "Securely store docker logins in macOS keychain" in Docker preferences. Login will fail with `Error saving credentials: error storing credentials - err: exit status 1, out: write permissions error` otherwise.

  ![disable-macOS-docker-login-keychain](https://user-images.githubusercontent.com/40004/33305360-d3e8cf28-d433-11e7-9b37-d29ab142ddd9.png)

- [jq](https://stedolan.github.io/jq/download/) (latest)
- [ntp](http://www.ntp.org/) (Optional. Install this if the build logs in Shippable UI don't appear in the correct order.)
