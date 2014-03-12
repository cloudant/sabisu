sabisu
======

A sensu web ui powered by [Cloudant](https://cloudant.com)

Features
========

 * Full text search (based on [lucene](http://lucene.apache.org/))
 * Complex search, filtering, and sorting
 * Statistical Analysis of your search/query
 * Real-time streaming updates to the event list and stats (non-polling)
 * Silence with expiration timeout, unsilence on resolve, or never expire
 * Create views of your environment and save, bookmark, and share them with your colleagues.

Installation
============

Sabisu was designed to be deployed to [heroku](http://heroku.com). There is [plenty of documentation]() on how to deploy a ruby app to heroku.

### Environment Variables

 * SABISU_ENV: which environment to start sabisu in (produciton or development)
 * PORT: http port to run sabisu on
 * CLOUDANT_USER: cloudant user (recommended to use [api keys](http://docs.cloudant.com/api/authz.html?highlight=key))
 * CLOUDANT_PASSWORD: cloudant password or api key
 * CLOUDANT_URL: your cloudant url (typically <username>.cloudant.com)
 * CLOUDANT_CURRENTDB: name of db to store current events (ie sensu_current_prod)
 * CLOUDANT_HISTORYDB: name of the db to store historical events (ie sensu_history_prod)
 * API_URL: your sensu api url
 *  API_PORT: your sensu api port
 * API_USER: your sensu api username
 * API_PASSWORD: your sensu api password
 * UILOGIN_USER: username to log into sabisu webui or api
 * UILOGIN_PASSWORD: password to log into sabisu webui or api
 * CUSTOM_FIELDS - an array of custom fields_

Development Environment
=======================

To setup sabisu for local development, 

1. first setup/install [RVM](https://rvm.io/) (or something like it). Its a good idea to keep your dev environment separate from your system ruby.
2. clone the repo locally
3. Create a `.env` file to setup your environment variables (see `Environment Variables` above).
4. Source the file (`source .env`)
5. Next run `bundle install`
6. To startup sabisu locally, run `foreman start`
7. In your browser, visit [localhost:8080](http://localhost:8080)
