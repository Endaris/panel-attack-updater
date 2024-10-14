~~A somewhat generic updater for love games without dependencies, mostly intended for games with an open/free license.~~  
The updater for the game Panel Attack. You can adapt it for other love games relatively easily.
Some of the options may seem impractical, alien and overly specific for how bad of a solution they present.  
They were (at least partially) implemented to serve the predecessor of this tool without having to change the server side of things in the same go in order to let users migrate to the new updater at their own pace.

# Configuration

## releaseStreams.json

Configure `releaseStreams.json` to decide which different release streams exist, from which source they update and how they are versioned.

```Json
{
    "releaseStreams":
    [
        {
            "name":"releaseStream1",
            "versioningType":"semantic",
            "serverEndPoint":
            {
                "type":"github",
                "repository":"love2d/love"
            }
        },
        {
            "name":"releaseStream2",
            "versioningType": "timestamp",
            "serverEndPoint":
            {
                "type": "filesystem",
                "url": "http://example.com/updates/",
                "prefix":"example-"
            }
        }
    ]
}
```

### name
For name, choose whatever so long as you avoid duplicates, these function as the unique identifier!  

### versioningType

For versioningType there are currently 2 supported settings.

#### semantic
For semantic versioning, `major.minor.patch-prereleasestring+metadata`.  
Your semantic version must specify at least `major.minor`.  
If you wish to utilize prerelease and metadata, you must specify the full `major.minor.patch` before it, e.g. `1.0-alpha` is not valid but `1.0.0-alpha` is.

#### timestamp
For versioning in a custom datetime format suitable to be used in file names, `yyyy-MM-dd_hh-mm-ss`

### serverEndPoint

This is a set of options that may differ in details depending on the selected type.

#### github

The github server end point looks for versions via the github api for releases.  
To determine the final url a field `repository` has to be supplied in the format `githubUser/repositoryName`.  
When using github as the endpoint, the name (not the tag!) of the release is used as string representation of the version.

#### filesystem

This was implemented against the standard html presentation of a readable directory on a nginx webserver but may work on other websites as well.  
The body of the response to a GET request on the requested `url` will be matched with `'href="' .. prefix .. "[^%s%.].love"` and all matches will be interpreted as versions.  
The part inbetween that is getting matched by `[^%s%.]` is used as the string representation of the version.

## launch.json

Stores the user's current starting configuration.

### activeReleaseStream

This has to refer to the unique name of one of the release streams specified in releaseStreams.json.  

### activeVersion

Specifies the version the user currently has selected in the string representation of that release stream's versioning type.  
If not present, the user uses the latest version of the release stream.  
The idea here is to allow users to specifically select older versions they may have installed, effectively allowing them to opt out of updates or selecting an older version.  
In the current iteration, downloading a new version as part of the startup always causes the new version to be set as the active version.

# Usage

Set the identity of the updater to the identity of the game so they share their save directory.  
Edit `releaseStreams.json` to suit your needs.  
In `config.json` configure only the `activeReleaseStream` to the one you wish your players to start with as a fallback, do not configure `activeVersion`.  
Zip, rename and possibly fuse the updater for release as usual.  
In general it is advisable to embed a fallback version.

## Embedding a fallback version

In case of your players not having internet access the first time they open your game, they should have a version available for offline use, even if it is outdated.  
To embed a version of your game, create a directory with the name of the active release stream chosen in your `config.json` at the top level.  
Inside this directory, create another directory that holds the minimum possible version for the release stream's versioning type. For semantic versioning this would be `0.0.0-norelease` or similar, for timestamp it would be `0`.
Put your .love or .zip file inside the folder.  
The updater will identify this embedded version as the base version for the release stream and download the most recent version to start in its stead if it can find one on first startup. If an update is not successful, it will boot with the embedded version.

## Making an informed decision on externalstorage on Android

The updater basically launching the game in itself and aiming to provide control over updates and release stream choice in the game itself means that both the updater and the game **need** to use the same save directory.  
Normally that is the standard but on Android this can be compromised through having diverging `externalstorage` settings.  
Due to that it is basically impossible to change your mind on this setting later on without explicitly asking your users to redownload the updater with a new setting (and that still does not migrate their data to the new save directory!).  
Regardless of which setting you choose, the files will be relatively inaccessible for writing, however, with `externalstorage` set to `true` it is quite a bit easier for users to at least read them.

# Distribution

## love-build

This project's `build.lua` is a config file for use with [love-build](https://github.com/ellraiser/love-build).

## Supporting unsecured http

The used [https library](https://github.com/love2d/lua-https) depends on OS specific implementations and thus extra steps have to be taken, specifically on Mac OS X, to allow requests to unsecured endpoints.  
The respective implementation defaults the `NSExceptionAllowsInsecureHTTPLoads` key responsible for toggling the behaviour to `false`, making requests to unsecured http servers fail with status code 0.  
After packaging the project with love-build, the resulting artifact for Mac can be unzipped and the pseudo-xml `Contents/Info.plist` can be supplied with domain specific exceptions for this behaviour, e.g.:
```Xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>yourdomain.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```
After rezipping, unsecured http requests against that domain will work, additional configuration options can be found in [Apple's documentation](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW44).