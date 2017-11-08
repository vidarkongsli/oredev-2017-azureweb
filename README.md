# Talk: Continuous delivery with Azure Web apps
Code for talk at Øredev 2017.
Slides are [here](./presentation/Presentation.pdf).

## Tools
* [Project Kudu](https://github.com/projectkudu/kudu)
* [Azure CLI 2.0](http://bit.ly/az-cli)
* [Kuduscript](https://github.com/projectkudu/KuduScript) 
* [Visual Studio Code](https://code.visualstudio.com/)
* [Iwr-tests (PowerShell script)](http://bit.ly/iwr-tests)
* [Kudu-to-slack-relay (Azure function)](http://bit.ly/kudu2slack)

## Note
* In the presentation, I forgot to add `$ProgressPreference='silentlycontinue` in the deploy script. This is needed for running `Invoke-WebRequest` on the server. Otherwise, it will try to show a progress bar, and the script will crash.