# puppet-consulr
Dynamic puppet manifests using [consul](https://www.consul.io/)

## getting started
Add a key to consul:
```
curl -X PUT <uri>/v1/kv/<nodes_prefix>/<facter_prefix_key>/some_key -d 'some value'
```

Add this line to **site.pp** or some place where it can be called as top-scope variable:
```
$something_fancy = consulr_kv('http://localhost:8500', 'nodes', 'ec2_instance_id')
```

Then you can call `$something_fancy` anywhere in your puppet environment like so:
```
$::something_fancy['some_key']
```

## parameters
`consulr_kv` takes 3 parameters, all are required.
```
consulr_kv(uri, nodes_prefix, facter_prefix_key)
```

* `uri`: The URI to connect to HTTP API, usually it's `http://localhost:8500` (no trailing `/`).
 
* `nodes_prefix`: The prefix for all nodes-related keys: `<uri>/<nodes_prefix>/<facter_prefix_key>`.

* `facter_prefix_key`: The Facter prefix key is the **name** of the key of one of the facts unique to the node.

  * If it's an EC2 instance, the logical choice would be the `ec2_instance_id` fact since it's unique for all the instances and doesn't have too many special characters (ex. `i-a8caf087`)

  * For non-EC2 instances the `hostname` fact is a good choice but `fqdn` is probably not (although it might work). Basically choose something which doesn't have too many special characters, but is unique.

  * **DO NOT** pass the fact like `$::hostname`, just pass the fact's key name as a string `'hostname'`. For a list of all facts run `facter -p` on the instance.

## A real-world scenario
Imagine for a minute you want to upgrade Django from 1.5 to 1.6 across 100 instances. You've tested the newer version and decided to upgrade in production.

Usually the upgrade is all or nothing, meaning, you can either upgrade Django on all the nodes at once or none at all. But what if you want to do a more controlled rollout? If you want to upgrade in batches of 10, follow the steps below.

* Add a `django_version` key with a value to consul on various instances (you can probably automate this with a simple bash batch script).
  * The `<facter_prefix_value>` must be unique to each node **and** must come in the beginning of the key name
    * **BAD**: `/v1/kv/something/<nodes_prefix>/or/the/other/<facter_prefix_value>/django_version`
    * **GOOD**: `/v1/kv/<nodes_prefix>/<facter_prefix_value>/something/or/the/other/django_version`
```
Format:
curl -X PUT <uri>/v1/kv/<nodes_prefix>/<facter_prefix_value>/<key> -d '<value>'

Example:
curl -X PUT http://localhost:8500/v1/kv/nodes/i-a8caf087/django_version -d "0.1.6"
curl -X PUT http://localhost:8500/v1/kv/nodes/i-e4b18acb/django_version -d "0.1.6"
curl -X PUT http://localhost:8500/v1/kv/nodes/i-8581df78/django_version -d "0.1.6"
curl -X PUT http://localhost:8500/v1/kv/nodes/i-359717e3/django_version -d "0.1.6"
```
* In **site.pp** initialize the function:

```$consulr_kv = consulr_kv('http://localhost:8500', 'nodes', 'ec2_instance_id')```

* In one of your modules, add a conditional like so:
  * Use the variable as a top-scope (`$::some_var`)
  * Always omit`<nodes_prefix>/<facter_prefix_value>` from the key name
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
curl -X PUT http://localhost:8500/v1/kv/<nodes_prefix>/<facter_prefix_value>/django/production/version -d "0.1.6"
```
Again, omit `<nodes_prefix>/<facter_prefix_value>` when calling the key:
```
$::consulr_kv['django/production/version'] # 0.1.6
```

## contribute
You know the deal: fork and pull
