# macOS 10.12 Sierra

macOS 10.12 nodes can be initialised with the Shippable agent to run runSh builds. Some of the pre-requisites for installing it are listed below. After installing the pre-requisites, please read about [how to add the node using Shippable UI](http://docs.shippable.com/platform/tutorial/runtime/custom-nodes/). We do not support auto initialisation for macOS at this time. Only manual scripts are supported.

Please do **not** run the script as sudo. Instead, input the password if the script prompts at the time of running it.

## Prerequisites
- [git](https://git-scm.com/download/mac) (latest)
- [Node.js](https://nodejs.org/en/download/) (v4.8.6)
- [Docker](https://docs.docker.com/docker-for-mac/install/) (v17.x.x)
- [ntp](http://www.ntp.org/) (Optional. Install this if the build logs in Shippable UI don't appear in the correct order.)
