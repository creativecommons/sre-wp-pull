# sre-wp-pull

Creative Commons Site Reliability Engineering WordPress Data Pull

**:warning: Destroys and replaces destination data**


## To Do

- WordPress Multisite rename
- Additional testing/validation


## Assumptions

1. Destination web hosting and WordPress are configured indipendently (ex. by
   SaltStack)
2. WordPress source data was created using
   [/states/wordpress/files/backup_wordpress.sh][backup] found in the
   [creativecommons/sre-salt-prime][salt-prime] repository.

[salt-prime]: https://github.com/creativecommons/sre-salt-prime
[backup]: https://github.com/creativecommons/sre-salt-prime/blob/master/states/wordpress/files/backup_wordpress.sh


## Use

1. Optionally, run [`backup_wordpress.sh`][backup-sh] on the source host
2. Clone this repository
3. Make a copy of one of the appropriate [`config_examples/`](config_examples/)
4. Execute script with config file as only argument. For example:
    ```shell
    ./wp-pull.sh chapters__stage
    ```


## Code of Conduct

[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md):
> The Creative Commons team is committed to fostering a welcoming community.
> This project and all other Creative Commons open source projects are governed
> by our [Code of Conduct][code_of_conduct]. Please report unacceptable
> behavior to [conduct@creativecommons.org](mailto:conduct@creativecommons.org)
> per our [reporting guidelines][reporting_guide].

[code_of_conduct]:https://creativecommons.github.io/community/code-of-conduct/
[reporting_guide]:https://creativecommons.github.io/community/code-of-conduct/enforcement/


## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).


## License

- [`LICENSE`](LICENSE) (Expat/[MIT][mit] License)

[mit]: http://www.opensource.org/licenses/MIT "The MIT License | Open Source Initiative"
