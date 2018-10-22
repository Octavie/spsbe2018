## SPSBE 2018 Demos
PowerShell scripts:
- DEMO SPA ARM - Simple SPA sample based on ARM template deployment with Environment variable
- DEMO SPA GEO ARM - Simple Geo redundant SPA sample based on ARM template deployment with Environment variable
- DEMO SPFx Deployment - Simple SPFx package deployment and site provisioning with PNP PowerShell.

## SPFx source project
Sample HelloWorld webpart

added gulp-environment.js to prepare package with different Name, ID per environment.

More info: [https://www.eliostruyf.com/gulp-task-to-change-environment-settings-in-sharepoint-framework-projects/](https://www.eliostruyf.com/gulp-task-to-change-environment-settings-in-sharepoint-framework-projects/)

### Build options
- gulp clean
- gulp change-pkg-settings --env tst
- gulp bundle --ship
- gulp package-solution --ship
