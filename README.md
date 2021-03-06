# NUcore Open

Open source version of Northwestern University Core Facility Management Software

## Quickstart

Welcome to NUcore! This guide will help you get a development environment up and running.

### Development within Docker Environment

We recommend running within a docker environment.
Benefits:
- All daemons, processes are running at all times (easier to develop features)

To do this:
1. [Install Docker and Docker Compose](https://docs.docker.com/docker-for-mac/install/)
1. Run `./docker-setup.sh`. This sets up your `database.yml` and `secrets.yml` files. It also does an intial `bundle install`.
1. The output of the previous set is a randomly generated secret. Copy and paste it into your `secrets.yml` file as the `secret_key_base`.
1. This will also finish setting up the database
1. Seed the database with demo data (optional) `docker-compose run app bundle exec rake demo:seed`
1. Run `docker-compose up`
1. Open http://localhost:3000

If you seeded the demo data, you can log in with admin@example.com/password

#### Email

We use [mailcatcher](https://mailcatcher.me/) as an SMTP server and web client. Visit <http://localhost:1080>.

#### Useful Commands

* **Rails Console:** `docker-compose exec app bundle exec rails c`
* **Command line in the container:** `docker-compose exec app bash`
* **Running tests:** Get a command line in the container and `bundle exec rspec`

### Development locally

It makes a few assumptions:

1. You write code on a Mac.
2. You have a running Oracle or MySQL instance with two brand new databases. (Oracle setup instructions [here](doc/HOWTO_oracle.md).)
3. You have the following installed:
    * [Ruby](http://www.ruby-lang.org/en)
    * [Bundler](http://gembundler.com)
    * [Git](http://git-scm.com)
    * [PhantomJS](http://phantomjs.org/)

### Spin it up

1. Download the project code from Github

    ```
    git clone git@github.com:tablexi/nucore-open.git nucore
    ```

2. Install dependencies

    ```
    cd nucore
    bundle install
    ```

3. Configure your databases

    ```
    cp config/database.yml.mysql.template config/database.yml
    ```

    Edit the adapter, database, username, and password settings for both the development and test DBs to match your database instance

4. Configure your secrets

  ```
  cp config/secrets.yml.template config/secrets.yml
  rake secret
  ```

  - Paste the output from `rake secret` into `config/secrets.yml` for both `development/secret_key_base` and `test/secret_key_base`

5. Set up databases

    ```
    rake db:create
    rake db:schema:load
    rake db:seed
    ```

_Known issue: if you run `db:setup` or all three in one rake command, the next time you run `db:migrate`, you will receive a `Table 'splits' already exists` error. Use the separate commands instead._

6. Seed your development database

    ```
    rake demo:seed
    ```

7. Configure your file storage

    By default, files are stored on the local filesystem. If you wish to use
    Amazon's S3 instead, create a local settings override file such as
    `config/settings/development.local.yml` or `config/settings/production.local.yml`
    and include the following, substituting your AWS settings:

    ```
    paperclip:
      storage: fog
      fog_credentials:
        provider: AWS
        aws_access_key_id: YOUR_S3_KEY_GOES_HERE
        aws_secret_access_key: YOUR_S3_SECRET_KEY_GOES_HERE
      fog_directory: YOUR_S3_BUCKET_NAME_GOES_HERE
      fog_public: false
      path: ":class/:attachment/:id_partition/:style/:safe_filename"
    ```

8. Start your server

    ```
    bin/rails s
    ```

9. Log in

    Visit http://localhost:3000

    `demo:seed` creates several users with various permissions. All users have the default password of `password`

    | Email/username     | Role |
    | ------------------ | ---- |
    | admin@example.com  | Admin|
    | ppi123@example.com | PI   |
    | sst123@example.com | Normal User |
    | ast123@example.com | Facility Staff |
    | ddi123@example.com | Facility Director |

10. Play around! You're running NUcore!

11. Run `delayed_job` to support in-browser email previews.

    Run delayed jobs indefinitely in the background:
    ```
    ./script/delayed_job start
    ```

    Or run delayed jobs once for one-off jobs:
    ```
    ./script/delayed_job run
    ```

### Test it

NUcore uses [Rspec](http://rspec.info) to run tests. Try any of the following from NUcore's root directory.

* To run all tests (this will take awhile!)

    ```
    rake spec
    ```

* To run just the model tests

    ```
    rake spec:models
    ```

* To run just the controller tests
    ```
    rake spec:controllers
    ```

#### Parallel Tests

You can run specs in parallel during local development using the [`parallel_tests`](https://github.com/grosser/parallel_tests) gem.

* Create additional databases:

    ```
    rake parallel:create
    ```

* Run migrations (only needed if building from scratch):

    ```
    rake parallel:create
    ```

  OR

    ```
    rake parallel:load_schema
    ```

* Copy development schema (repeat after migrations):

	```
    rake parallel:prepare
	```

* Run tests:

    ```
    rake parallel:spec
    ```

* Example RegEx patterns (ZSH users may require putting rake task in quotes to support args):

	```
    rake parallel:spec[^spec/requests] # every spec file in spec/requests folder
    rake parallel:spec[user]  # run users_controller + user_helper + user specs
    rake parallel:spec['user|instrument']  # run user and product related specs
    rake parallel:spec['spec\/(?!features)'] # run RSpec tests except the tests in spec/features
    ```

## Optional Modules

The following modules are provided as optional features via
[Rails engines](http://guides.rubyonrails.org/engines.html). These are enabled
by adding the appropriate engine to your Gemfile (all are on by default). They
exist in the `vendor/engines` directory.

* Accept Credit Cards & Purchase Orders (c2po)
* Connect to Dataprobe Power Relays (dataprobe)
* Link orders together as a Project (projects)
* [Sanger Sequencing order form and well plate management](vendor/engines/sanger_sequencing/README.md)
* [Split charges between different accounts](vendor/engines/split_accounts/README.md)
* [Authenticate against an LDAP server](vendor/engines/ldap_authentication/README.md)
* [Authenticate with SSO via SAML](vendor/engines/saml_authentication/README.md)

Engine-specific migrations should live in the engine's `db/migrate` directory and
use an engine initializer to add that path to the list of paths Rails checks. If
you need to disable an engine, you can undo all of the engine's migrations with
the `rake engines:db:migrate_down[ENGINE_NAME]` task.

## Learn more

There are valuable resources in the NUcore's doc directory.

* Want to conform to the project's established coding standards? [**See coding_standards.md**](doc/coding_standards.md)

* Want to know more about the instrument pricing model? [**See instrument_pricing.md**](doc/instrument_pricing.md)

* Need to move changes between nucore-open and your fork? [**See HOWTO_forks.txt**](doc/HOWTO_forks.md)

* Need help getting Oracle running on your Mac? [**See HOWTO_oracle.md**](doc/HOWTO_oracle.md)

* Want to authenticate users against your institution's LDAP server? [**See the `ldap_authentication` engine**](vendor/engines/ldap_authentication/README.md)

* Need to use a 3rd party service with your NUcore? [**See HOWTO_external_services.txt**](doc/HOWTO_external_services.md)

* Need to asynchronously monitor some aspect of NUcore? [**See HOWTO_daemons.txt**](doc/HOWTO_daemons.txt)

* Want to integrate with Form.io? [**See form.io_tips_and_tricks**](doc/form.io_tips_and_tricks.docx)
