/**

  Origin of this code: https://www.eliostruyf.com/gulp-task-to-change-environment-settings-in-sharepoint-framework-projects/

  This gulp task can be used to update environment configuration of the current project.

  All settings are stored in a file: ./config/package-solution-env-settings.json

  Example settings:
  {
    "environments": [{
      "environment": "default",
      "id": "7E60EE1A-512E-4E2B-88B2-EF61103936F8",
      "name": "spfxbuild-client-side-solution",
      "zip": "solution/spfxbuild.sppkg",
      "cdn": "https://tenant.sharepoint.com/cdn",
      "entries": [{
        "id": "9fddb786-2717-43f0-8455-865a3a837cf0",
        "location": "./src/webparts/buildWp/BuildWpWebPart.manifest.json"
      }]
    }, {
      "environment": "test",
      "id": "b8a92179-8cca-453c-aad4-1b50b82a2375",
      "name": "spfxbuild-client-side-solution-test",
      "zip": "solution/spfxbuild-test.sppkg",
      "cdn": "https://tenant.sharepoint.com/spfxtest",
      "entries": [{
        "id": "b2e6a053-0abe-474d-852f-dcbcaf5bb35c",
        "location": "./src/webparts/buildWp/BuildWpWebPart.manifest.json"
      }]
    }
  }

  Prerequisites:

  To make use of this task, first install the uuid module to your project: npm install uuid --save-dev --save-exact

  Using this task:

  First create a new file called: "gulpfile-change-packaging-settings.js" in your project. Add the following line "require('./gulpfile-change-packaging-settings');" in the "gulpfile.js" just before this line: build.initialize(gulp);

  After the code is added, you could run the following tasks:

  - gulp change-pkg-settings
    - This will run the default configuration. If it is the first time you run this, it will backup all the settings. So it is recommended to use it the very first time.
  - gulp change-pkg-settings --env test
    - Tell to change the settings to a test build. If it is the first time, all new IDs will be created for the package, web parts and extensions.
  - gulp change-pkg-settings --env test --cdnpath https://tenant.sharepoint.com/library
    - Change to a test build and update the CDN location. This is recommended the first time you change your environment. Otherwise you will use the same CDN location for all environments.
  - gulp change-pkg-settings --check
    - Check which settings have been stored.
 **/


'use strict';

const build = require('@microsoft/sp-build-web');
const logging = require('@microsoft/gulp-core-build');
const fs = require('fs');
const uuidV4 = require('uuid/v4');
const chalk = require('chalk');
const decomment = require('decomment');

const packageFilePath = './config/package-solution.json';
const cdnFilePath = './config/write-manifests.json';
const configFilePath = './config/config.json';
const settingsFilePath = './config/package-solution-env-settings.json';

build.task('change-pkg-settings', {
  execute: (config) => {
    return new Promise((resolve, reject) => {
      /* Retrieve the arguments */
      const env = config.args['env'] || "default";
      const check = config.args['check'] || false;
      const cdn = config.args['cdnpath'] || "";

      /* Check if the user wants to log the environment information */
      if (check) {
        // Start the environment logging
        environmentLogging();
        // Complete the task
        resolve();
        return;
      }

      /* Start processing the package changes */
      // Retrieve the package solution file
      let pkgSolJSON = JSON.parse(fs.readFileSync(packageFilePath));
      // Retrieve the CDN manifest file
      let cdnJSON = JSON.parse(fs.readFileSync(cdnFilePath));
      // Retrieve the config file
      const configJSON = JSON.parse(fs.readFileSync(configFilePath));

      // Get the package settings - only available if you already used this task
      let pkgSettingsJSON = {
        environments: []
      };
      // Retrieve the environment information from the settings file if it exists
      if (fs.existsSync(settingsFilePath)) {
        const contents = fs.readFileSync(settingsFilePath);
        if (contents.length > 0) {
          pkgSettingsJSON = JSON.parse(contents);
        }
      }
      // Check for environment information
      if (pkgSettingsJSON.environments.length === 0) {
        // Get all the developer entries (web parts and extensions)
        const devEntries = getDevEntries(configJSON);
        // Store the current settings as the default
        storeEnvironmentSettings(pkgSettingsJSON, pkgSolJSON, cdnJSON.cdnBasePath, devEntries, 'default');
      }

      // Retrieve of create the environment information
      logging.log(`Configuring settings for environment: ${env}`);
      const cdnPath = cdn === "" ? cdnJSON.cdnBasePath : cdn;
      const crntEnv = getEnvironmentInfo(pkgSettingsJSON, pkgSolJSON, cdnPath, env);
      pkgSolJSON.solution.name = crntEnv.name;
      pkgSolJSON.solution.id = crntEnv.id;
      pkgSolJSON.paths.zippedPackage = crntEnv.zip;

      // Check if the developer entries are retrieved, otherwise new IDs have to be generated
      if (typeof crntEnv.entries === "undefined") {
        crntEnv.entries = [];
      }
      // Go over all the bundles
      for (const bundleName in configJSON.bundles) {
        const bundle = configJSON.bundles[bundleName];
        // Go over every component in the bundles
        if (typeof bundle.components !== "undefined") {
          bundle.components.forEach(component => {
            const crntEntry = crntEnv.entries.filter(e => e.location === component.manifest);
            // Check if the entry existed
            if (crntEntry.length === 0) {
              crntEnv.entries.push({
                id: crntEntry.id = uuidV4(),
                location: component.manifest
              });
            }
          });
        }
      }

      // Update the CDN path to the current environment
      crntEnv.cdn = cdn === "" ? crntEnv.cdn : cdn;
      cdnJSON.cdnBasePath = crntEnv.cdn;
      logging.log(`Using the following CDN location: ${crntEnv.cdn}`);

      // Store the settings
      logging.log(`Writing settings to environments file: ${settingsFilePath}`);
      storeEnvironmentSettings(pkgSettingsJSON, pkgSolJSON, crntEnv.cdn, crntEnv.entries, env);
      // Write the package information to the JSON file
      logging.log(`Updating package solution file: ${packageFilePath}`);
      fs.writeFileSync(packageFilePath, JSON.stringify(pkgSolJSON, null, 2));
      // Write the CDN path to the manifest file
      logging.log(`Updating CDN in the manifest file: ${cdnFilePath}`);
      fs.writeFileSync(cdnFilePath, JSON.stringify(cdnJSON, null, 2));
      // Update all the IDs in the manifest files
      crntEnv.entries.forEach(entry => {
        const manifestContent = fs.readFileSync(entry.location, 'utf8');
        const manifestJSON = JSON.parse(decomment(manifestContent));
        if (manifestJSON.id !== entry.id) {
          logging.log(`Updating ID in the manifest file: ${entry.location}`);
          logging.log(chalk.green(`OLD: ${manifestJSON.id} - NEW: ${entry.id}`));
          manifestJSON.id = entry.id;
          fs.writeFileSync(entry.location, JSON.stringify(manifestJSON, null, 2));
        }
      });
      resolve();
    });
  }
});


/**
 * Log the current stored environment information
 */
function environmentLogging() {
  if (fs.existsSync(settingsFilePath)) {
    const settingContents = fs.readFileSync(settingsFilePath);
    const pkgSolJSON = JSON.parse(fs.readFileSync(packageFilePath));

    if (settingContents.length > 0) {
      const settings = JSON.parse(settingContents);
      if (settings.environments.length > 0) {
        logging.log('Found the following environment information:');
        settings.environments.forEach((environment) => {
          logging.log(`- ${environment.environment}: ${environment.id} ${pkgSolJSON.solution.id === environment.id ? chalk.green.bold('(current)') : ''}`);
          logging.log(`  ${environment.cdn}`);
        });
      } else {
        // File exists, but no information is stored
        logging.warn('No environment information found!');
      }
    } else {
      // File exists, but no information is stored
      logging.warn('Environment file is empty');
    }
  } else {
    // No environment file is found
    logging.error('No environment information file found!');
  }
}


/**
 * Function which returns the environment information for the specified environment
 *
 * @param {*} settingsJSON
 * @param {*} solutionJSON
 * @param {string} cdnPath
 * @param {string} env
 */
function getEnvironmentInfo(settingsJSON, solutionJSON, cdnPath, env) {
  // Check if the environment information exists
  const solutionInfo = getEnvironment(settingsJSON, env);
  if (solutionInfo !== null) {
    return solutionInfo;
  }

  // Get the default environment information
  const defaultInfo = getEnvironment(settingsJSON, 'default');
  let solution;
  if (defaultInfo !== null) {
    const zipPkg = defaultInfo.zip.split('.sppkg');
    solution = {
      id: uuidV4(),
      name: `${defaultInfo.name}-${env}`,
      zip: `${zipPkg[0]}-${env}.sppkg`,
      cdn: defaultInfo.cdn,
      entries: []
    };
  } else {
    const zipPkg = solutionJSON.paths.zippedPackage.split('.sppkg');
    solution = {
      id: uuidV4(),
      name: `${solutionJSON.solution.name}-${env}`,
      zip: `${zipPkg[0]}-${env}.sppkg`,
      cdn: cdnPath,
      entries: []
    };
  }

  return solution;
}


/**
 * Function to get the environment information
 *
 * @param {*} settingsJSON
 * @param {string} env
 */
function getEnvironment(settingsJSON, env) {
  for (let i = 0; i < settingsJSON.environments.length; i++) {
    let crntEnv = settingsJSON.environments[i];
    if (crntEnv.environment === env) {
      return crntEnv;
    }
  }
  return null;
}


/**
 * Function that will store the environment information to a seperate JSON file
 *
 * @param {*} settingsJSON
 * @param {*} solutionJSON
 * @param {string} cdnPath
 * @param {*} devEntries
 * @param {string} env
 */
function storeEnvironmentSettings(settingsJSON, solutionJSON, cdnPath, devEntries, env) {
  let found = false;

  // Loop and update the environment record
  for (let i = 0; i < settingsJSON.environments.length; i++) {
    let crntEnv = settingsJSON.environments[i];
    if (crntEnv.environment === env) {
      crntEnv.id = solutionJSON.solution.id;
      crntEnv.name = solutionJSON.solution.name;
      crntEnv.zip = solutionJSON.paths.zippedPackage;
      crntEnv.cdn = cdnPath;
      crntEnv.entries = devEntries;
      found = true;
    }
  }

  // If the current environment was not find, we will add it
  if (!found) {
    settingsJSON.environments.push({
      environment: env,
      id: solutionJSON.solution.id,
      name: solutionJSON.solution.name,
      zip: solutionJSON.paths.zippedPackage,
      cdn: cdnPath,
      entries: devEntries
    });
  }

  fs.writeFileSync(settingsFilePath, JSON.stringify(settingsJSON, null, 2))
}


/**
 * Function to retrieve all developer manifests of your webparts and extensions
 *
 * @param {*} configJSON
 */
function getDevEntries(configJSON) {
  let entries = [];

  if (configJSON.bundles) {
    logging.log(`Found the following developer entries:`);

    for (const bundleName in configJSON.bundles) {
      const bundle = configJSON.bundles[bundleName];
      if (typeof bundle.components !== "undefined") {
        // Loop over all the component manifests
        bundle.components.forEach(component => {
          // Check if the manifest property exist
          if (typeof component.manifest !== "undefined") {
            // Check if the manifest file exists
            if (fs.existsSync(component.manifest)) {
              const manifestCnts = fs.readFileSync(component.manifest, 'utf8');
              if (manifestCnts.length > 0) {
                const manifest = JSON.parse(decomment(manifestCnts));
                logging.log(`- ${manifest.id}`);
                entries.push({
                  id: manifest.id,
                  location: component.manifest
                });
              }
            }
          }
        });
      }
    }
  }

  return entries;
}
