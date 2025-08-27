<?php
return [
        'App' => [
                'fullBaseUrl' => 'https://passbolt.local'
        ],
        'Email' => [
                'default' => [
                        'transport' => 'Smtp',
                        'host' => 'smtp.gmail.com',
                        'port' => 587,
                        'timeout' => 30,
                        'username' => 'ismael.mouloungui@groupebatimat.com',
                        'password' => 'hmob ypbv ooou heee',
                        'client' => null,
                        'tls' => true,
                        'url' => null,
                ],
        ],
        'Passbolt' => [
                'ssl' => [
                        'force' => true,
                        'setup' => true
                ],
                'email' => [
                        'validate' => [
                                'domain' => false
                        ]
                ]
        ]
];