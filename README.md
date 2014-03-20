[![Build Status](https://magnum.travis-ci.com/cloudant/sabisu.png?token=r6PdrwNFR1nUzFeEEiQ6&branch=master)](https://magnum.travis-ci.com/cloudant/sabisu)
sabisu
======

A sensu web ui powered by [Cloudant](https://cloudant.com)

Features
========

 * Full text search (based on [lucene](http://lucene.apache.org/))
 * Complex search, filtering, and sorting
 * Smart autocomplete to help you find what you're looking for
 * Statistical analysis of your search/query (faceting)
 * Real-time streaming updates to the event list and stats (non-polling)
 * Add custom attributes to your sensu events and make them searchable, indexed, and give them statistical context
 * Easy "drill down" by clicking on any client, check, status or even custom attributes to see more events like them
 * Silence with expiration timeout, unsilence on resolve, or never expire
 * Create views of your sensu environment and save, bookmark, and share them with your colleagues.

Demo
====

If you want to take sabisu for a test drive, jump over to the [demo](http://demo.sabisuapp.org/)

Screenshots
===========

![Dashboard](https://raw.github.com/cloudant/sabisu/master/screenshots/example.png "dashboard")

Requirements
============

[Sensu](https://github.com/sensu/sensu) >= [0.12.1](https://github.com/sensu/sensu/blob/master/CHANGELOG.md#0121---2013-11-02)

Installation
============

First, you'll need a [Cloudant account](https://cloudant.com/sign-up/). Its free to sign-up and free to use, see [pricing details](https://cloudant.com/product/pricing/). Next, you'll need to create two databases. Commonly, you can call them `sensu_current` and `sensu_history`, but you can call them whatever you want. 

Next you'll want to create yourself api keys. You technically don't need to do this step, but it is recommended as best practices. You could use your cloudant username and password instead. To create api keys, you can do this via the webui or the [api](http://docs.cloudant.com/api/authz.html?highlight=api%20key). Create an api key on one of the database and give it full permissions (reader, writer, admin). Then grant the same API key to the other cloudant database you've created.

Once you've got that setup, the next step is integrating the cloudant database into sensu. To do this, follow [this documentation](https://github.com/cloudant/sabisu/blob/master/sensu-integration/README.md).

Sabisu was designed to be deployed to [heroku](http://heroku.com) for purposes of ease, but you can also deploy it on your own infrastructure. There is [omnibus repo](https://github.com/cloudant/omnibus-sabisu) for building packages for various platforms. There is [plenty of documentation](https://devcenter.heroku.com/articles/ruby-support) on how to deploy a ruby app to heroku. But you can also deployed to a server within your environment if desired.

### Environment Variables

 * SABISU\_ENV: which environment to start sabisu in (produciton or development)
 * PORT: http port to run sabisu on
 * CLOUDANT\_USER: cloudant user (recommended to use [api keys](http://docs.cloudant.com/api/authz.html?highlight=key))
 * CLOUDANT\_PASSWORD: cloudant password or api key
 * CLOUDANT\_URL: your cloudant url (typically USERNAME.cloudant.com)
 * CLOUDANT\_CURRENTDB: name of db to store current events (ie sensu_current)
 * CLOUDANT\_HISTORYDB: name of the db to store historical events (ie sensu_history)
 * API\_URL: your sensu api url
 * API\_PORT: your sensu api port
 * API\_USER: your sensu api username
 * API\_PASSWORD: your sensu api password
 * UILOGIN\_USER: username to log into sabisu webui or api
 * UILOGIN\_PASSWORD: password to log into sabisu webui or api
 * CUSTOM\_FIELDS - an array of custom fields to support. Out of the box, sabisu supports `client`, `check`, `status`, `state_change`, `occurrence`, `issued`, and `output`. These fields are indexed, searchable, and sometimes faceted (statistics). In addition to these you can add your own custom fields based on client and check attributes that your sensu architecture sends. Some example ideas are, environment, cluster, datacenter, documentation url, metrics url, pod, rack, team, paging or non-paging, provider, ec2 availability zone, etc. Whatever would make sense in your environment to make events more discoverable.
    - example: `[{"name": "environment", "path": "client.environment", "facet": true, "type": "str", "index": true}]`
      more examples: see config.rb
      * name: [string] name of the attribute (will be the field name in sabisu)
      * path: [string] path to the attribute with the sensu event
      * facet: [boolean] include in faceting (statistics). Only supports ints and strings (not boolean, arrays, hashes, etc)
      * type: [string] variable type this attribute value will have, supports [ str, int, url ]
      * index: [boolean] make this attribute searchable

Development Environment
=======================

To setup sabisu for local development, 

1. first setup/install [RVM](https://rvm.io/) (or something like it, ie [rbenv](http://rbenv.org/)). Its a good idea to keep your dev environment separate from your system ruby.
2. clone the repo locally
3. Create a `.env` file to setup your environment variables (see [Environment Variables](https://github.com/cloudant/sabisu/blob/master/README.md#environment-variables) above).
4. Source the file (`source .env`)
5. Next run `bundle install`
6. To startup sabisu locally, run `foreman start`
7. In your browser, visit [localhost:8080](http://localhost:8080)
