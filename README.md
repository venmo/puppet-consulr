# puppet-consulr
Dynamic puppet manifests using [consul](https://www.consul.io/)

## getting started
Add a key to consul:
```
curl -X PUT <uri>/v1/kv/<nodes_prefix>/<facter_prefix>/some_key -d 'some value'
```

Add this line to **site.pp** or some place where it can be called as top-scope variable:
```
$something_fancy = consulr_kv()
```

Then you can call `$something_fancy` anywhere in your puppet environment like so:
```
$::something_fancy['some-key']
```

## parameters
`consulr_kv` takes a config hash with the following defaults:
```
consulr_kv({
  'uri'           => 'http://localhost:8500',
  'nodes_prefix'  => 'nodes',
  'facter_prefix' => 'hostname',
  'value_only'    => true,
  'base64_decode' => true,
  'ignore_404'    => true,
  'token'         => false,
  'timeout'       => 5,
})
```

* `uri`: The URI to connect to HTTP API, usually it's `http://localhost:8500` (no trailing `/`).
 
* `nodes_prefix`: The prefix for all nodes-related keys: `<uri>/<nodes_prefix>/<facter_prefix>`.

* `facter_prefix`: The Facter prefix is the **name** of the key of one of the facts unique to the node.

  * If it's an EC2 instance, the logical choice would be the `ec2_instance_id` fact since it's unique for all the instances and doesn't have too many special characters (ex. `i-a8caf087`)

  * For non-EC2 instances the `hostname` fact is a good choice. Basically choose something which doesn't have too many special characters, but unique.

  * **DO NOT** pass the fact like `$::hostname`, just pass the fact's name as a string `'hostname'`. For a list of all facts run `facter -p` on the instance.

* `value_only`: If set to `true` it will only return the value of the key in string format. If `false` it will return the entire hash as received from consul.

```
value_only = true
--
"aj test"
```

```
value_only = false
--
{
 "CreateIndex":7357,
 "ModifyIndex":7390,
 "LockIndex":0,
 "Key":"aj-test",
 "Flags":0,
 "Value":"aj test"
}
```

* `base64_decode`: If set to `true` the value returned from consul will automagically be decoded. If you choose to set it to `false` please ensure you use something like `base64()` from puppet-stdlib to convert the "raw" value.
```
base64_decode = true
--
"aj test"
```

```
base64_decode = false
--
"YWogdGVzdA=="
```

* `ignore_404`: If `true` puppet run will not fail when key doesn't exist. If set to `false` and the key is missing, puppet run will fail.

* `token`: Pass an ACL token when querying consul.

* `timeout`: Timeout, in seconds, while talking to the API.

## A real-world scenario
Imagine for a minute you want to upgrade Django from 1.5 to 1.6 across 100 instances. You've tested the newer version and decided to upgrade in production.

Usually the upgrade is all or nothing, meaning, you can either upgrade Django on all the nodes at once or none at all. But what if you want to do a more controlled rollout? If you want to upgrade in batches of 10, follow the steps below.

* Add a `django_version` key with a value to consul on various instances (you can probably automate this with a simple bash batch script).
  * The `<facter_prefix>` must be unique to each node **and** must come right after `<nodes_prefix>`
    * **BAD**: `/v1/kv/something/<nodes_prefix>/or/the/other/<facter_prefix>/django_version`
    * **GOOD**: `/v1/kv/<nodes_prefix>/<facter_prefix>/something/or/the/other/django_version`
```
Format:
curl -X PUT <uri>/v1/kv/<nodes_prefix>/<facter_prefix>/<key> -d '<value>'

Example:
curl -X PUT http://localhost:8500/v1/kv/nodes/i-a8caf087/django_version -d "0.1.6"
curl -X PUT http://localhost:8500/v1/kv/nodes/i-e4b18acb/django_version -d "0.1.6"
curl -X PUT http://localhost:8500/v1/kv/nodes/i-8581df78/django_version -d "0.1.6"
curl -X PUT http://localhost:8500/v1/kv/nodes/i-359717e3/django_version -d "0.1.6"
```
* In **site.pp** initialize the function:

```
$consulr_kv = consulr_kv({
  'facter_prefix' => 'ec2_instance_id'
})
```

* In one of your modules, add a conditional like so:
  * Use the variable as a top-scope (`$::some_var`)
  * Always omit`<nodes_prefix>/<facter_prefix>/` from the key name
    * **BAD**: `$::consulr_kv['nodes/i-a8caf087/django_version']`
    * **GOOD**: `$::consulr_kv['django_version']`
```
if $::consulr_kv['django_version'] == '0.1.6' {
  package { 'python-django': ensure => '0.1.6' }
} else {
  package { 'python-django': ensure => installed }
}

### OR ###

$django_version = $::consulr_kv['django_version'] ? {
  '0.1.6'  => $::consulr_kv['django_version'],
  default  => '0.1.5',
}

package {'python-django': ensure => $django_version }
```

## go deep (or go home)
You can call deep-nested keys just as easily:
```
curl -X PUT http://localhost:8500/v1/kv/<nodes_prefix>/<facter_prefix>/django/production/version -d "0.1.6"
```
Again, omit `<nodes_prefix>/<facter_prefix>/` when calling the key:
```
$::consulr_kv['django/production/version'] # 0.1.6
```

## contribute
You know the deal: fork and pull
