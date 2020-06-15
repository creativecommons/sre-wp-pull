# sre-wp-pull

Creative Commons Site Reliability Engineering WordPress Data Pull

> :warning: **Destroys and replaces destination data**


## Code of Conduct

[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md):
> The Creative Commons team is committed to fostering a welcoming community.
> This project and all other Creative Commons open source projects are governed
> by our [Code of Conduct][code_of_conduct]. Please report unacceptable
> behavior to [conduct@creativecommons.org](mailto:conduct@creativecommons.org)
> per our [reporting guidelines][reporting_guide].

[code_of_conduct]:https://opensource.creativecommons.org/community/code-of-conduct/
[reporting_guide]:https://opensource.creativecommons.org/community/code-of-conduct/enforcement/


## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).


## Assumptions

1. `DEST_HOST`:
   1. Web hosting and WordPress are configured independently (ex. by
      SaltStack)
      - `wp-config.php` is already setup
      - user has appopriate permissions (ex. member of `www-data`)
      - [WP-CLI][wp-cli] is already installed
   2. You may need to configure your users `.ssh/config`. For example,
      `chapters_stage` requires the following entry:
        ```
        Host 10.22.10.14
            ProxyJump 10.22.10.10
        ```
2. `SOURCE_HOST`:
   1. WordPress source data was created using
      [/states/wordpress/files/backup_wordpress.sh][backup] found in the
      [creativecommons/sre-salt-prime][salt-prime] repository.

[wp-cli]: https://wp-cli.org/
[salt-prime]: https://github.com/creativecommons/sre-salt-prime
[backup]: https://github.com/creativecommons/sre-salt-prime/blob/master/states/wordpress/files/backup_wordpress.sh


## Use

1. `SOURCE_HOST`: *(optional)*
   - run [`backup_wordpress.sh`][backup] on the
2. Local/laptop:
   1. Clone this repository
   2. Prepare configuration file
      1. Make a copy of one of the appropriate
         [`config_examples/`](config_examples/)
      2. Replace `FILEPATH` and `USERNAME` with your information
      3. Ensure `SOURCE_DB_FILE` and `SOURCE_UPLOADS_FILE` are valid files on
         the `SOURCE_HOST`.
   3. Execute script with config file as only argument. For example:
        ```shell
        ./wp-pull.sh chapters__stage
        ```


# Alternatives

(Only documenting CLI utitilities here. There are also many WordPress plugins
devoted to migrating, mirroring, and syncing.)

- [jplew/SyncDB][syncdb]: Bash script meant to take the tedium out of deploying
  and updating database-driven (eg Wordpress) websites. It rapidly synchronizes
  local and remote versions of a MySQL database, performs the necessary search
  and replace queries, then synchronizes all your uploads/binaries.

[syncdb]: https://github.com/jplew/SyncDB


## License

- [`LICENSE`](LICENSE) (Expat/[MIT][mit] License)

[mit]: http://www.opensource.org/licenses/MIT "The MIT License | Open Source Initiative"
