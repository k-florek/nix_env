# GVFS Mount Manager (gmount)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A flexible Python utility for managing network filesystem mounts with support for multiple backends. This tool simplifies mounting network drives by prompting for your password only once per invocation and creating easy-to-access symlinks in your home directory. Supports GVFS (GNOME Virtual File System), CIFS/SMB mounts, and S3 buckets via rclone.

## Features

- **Multiple Backend Support**:
  - GVFS backend for SMB/CIFS shares using `gio mount`
  - CIFS backend for direct SMB mounts using `mount.cifs` (useful when GVFS doesn't work)
  - S3 backend for mounting cloud storage buckets via `rclone`
- **Flexible Configuration**: JSON-based with environment variable expansion
- **SSH Tunnel Support**: Mount shares over secure SSH connections
- **Automatic Symlink Creation**: Easy access to mounted shares
- **Password Management**: Single password prompt per invocation
- **Color-coded Terminal Output**: Clear visual feedback
- **Complete Mount/Unmount Operations**: Simple one-command operations
- **Wrapper Scripts**: `gmount-mount` and `gmount-umount` for convenience

## Quick Start

1. Install dependencies: `pip install pexpect`
2. Create a `gmount.json` configuration file (see examples below)
3. Run `./gmount.py` to mount all configured shares
4. Run `./gmount.py -u` to unmount all shares

For detailed configuration options, see the sections below.

## Prerequisites

- Python 3.10+
- Required Python packages:
  - pexpect

### Backend-Specific Requirements

**GVFS Backend:**
- GNOME environment with GVFS support
- `gio` command (typically pre-installed on GNOME systems)

**CIFS Backend:**
- `mount.cifs` (usually from the `cifs-utils` package)
- `sudo` access for mount/umount operations
- Properly configured sudoers file (see CIFS section below)

**S3/Rclone Backend:**
- `rclone` installed and configured
- AWS credentials (via environment variables or rclone config)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/wslh-bio/miscellaneous_scripts
   cd gmount
   ```

2. Install dependencies:
   ```bash
   pip install pexpect
   ```

3. Make the script executable:
   ```bash
   chmod +x gmount.py
   ```

## Configuration

Create a `gmount.json` file in the same directory as the script. This configuration file defines the network shares you want to mount and how they should be accessed.

**Configuration File Location Priority:**
1. Path specified with `-c` or `--config` flag
2. Path set in `GMOUNT_CONFIG` environment variable
3. `gmount.json` in the current directory (default)

### Configuration Structure

```json
{
  "mounts": {
    "gvfs": [
      {
        "host"   : "server.example.com",
        "share"  : "/share",
        "local"  : "/home/@USERNAME/mounts/example",
        "options": "optional_mount_options",
        "domain" : "optional_domain_name"
      }
    ]
  }
}
```

### Configuration Fields

- **mounts**: The root object containing all mount definitions
  - **gvfs**: An array of GVFS backend mount configurations
  - **cifs**: An array of CIFS/SMB backend mount configurations
  - **s3**: An array of S3/rclone backend mount configurations 
    - **host**: The hostname or IP address of the remote file server
      - Identifies the network location of the server hosting the share
      - *Example*: `"fileserver.company.com"` or `"192.168.1.100"`
    
    - **share**: The share path on the remote server
      - Specifies which shared folder to access on the server
      - NOTE: `gio` mounts entire shares rather than specific subdirectories under the share
      - *Example*: `"/users"` or `"/public"`
    
    - **local**: The local path where the symlink to the gvfs mount will be created
      - Defines where the network share will appear in your local filesystem 
      - `gvfs` mounts are placed in `/var/run/user/${UID}/gvfs` by design so a symlink will be placed here instead
      - *Example*: `"/home/@USERNAME/mounts/server1"`
    
    - **options** (optional): Additional mount options
      - Provides extra parameters for customizing the mount behavior (currently unused)
      - *Example*: `"ro,uid=@FS_UID"` for read-only access
    
    - **domain** : Windows domain for authentication
      - Required when connecting to domain-controlled Windows shares
      - *Example*: `"WORKGROUP"` or `"MYDOMAIN"`

#### CIFS Backend Fields

- **host**: The hostname or IP address of the CIFS/SMB server
  - Can include port specification with format `hostname:port`
  - *Example*: `"fileserver.company.com"` or `"192.168.1.100:445"`

- **share**: The share name on the remote server  
  - Should start with `/` for proper UNC path formation
  - *Example*: `"/projects"` or `"/users"`

- **local**: The local path where the share will be mounted
  - Directory will be created if it doesn't exist
  - *Example*: `"/home/@USERNAME/mnt/projects"`

- **domain**: Windows domain for authentication
  - Required for domain-controlled shares
  - *Example*: `"WORKGROUP"` or `"MYDOMAIN"`

- **options**: Mount options for the CIFS mount
  - Use standard mount.cifs options
  - Comma-separated list of options
  - *Example*: `"username=@USERNAME,rw,uid=@USER_UID,gid=@USER_GID,file_mode=0644,dir_mode=0755,vers=3.0"`
  - Common options:
    - `vers=3.0` - Specify SMB protocol version
    - `uid=@USER_UID` - Set file ownership to current user
    - `gid=@USER_GID` - Set group ownership
    - `file_mode=0644` - Set default file permissions
    - `dir_mode=0755` - Set default directory permissions
    - `rw` - Mount read-write (default)
    - `ro` - Mount read-only

#### S3/Rclone Backend Fields

- **backend**: Backend tool to use (default: `"rclone"`)
  - *Example*: `"rclone"`

- **config**: Path to rclone configuration file
  - *Example*: `"/home/@USERNAME/.config/rclone/rclone.conf"`

- **local**: Local mount point for the bucket
  - *Example*: `"/home/@USERNAME/mnt/my-bucket"`

- **remote**: Rclone remote path (format: `remote_name:/bucket_name`)
  - The remote_name must match a configured remote in rclone.conf
  - *Example*: `"acloud:/my-bucket-0382"`

### Configuration Variables

The following variables are expanded automatically in the configuration:
- `@USERNAME`: Current logged-in username
  - *Example*: If current user is "john", `"/home/@USERNAME/mounts"` becomes `"/home/john/mounts"`

- `@FS_UID`: Effective user ID from filesystem perspective
  - *Purpose*: Used for file ownership in mount options
  - *Example*: If user ID is 1000, `"uid=@FS_UID"` becomes `"uid=1000"`

- `@FS_GID`: Effective group ID from filesystem perspective
  - *Purpose*: Used for file group ownership in mount options
  - *Example*: If group ID is 1000, `"gid=@FS_GID"` becomes `"gid=1000"`

- `@USER_UID`: Runtime user ID
  - *Purpose*: User ID of the user running gmount
  - *Example*: `"uid=@USER_UID"`

- `@USER_GID`: Runtime group ID
  - *Purpose*: Group ID of the user running gmount
  - *Example*: `"gid=@USER_GID"`


## SSH Tunnel Configuration and Usage

SSH tunnels provide a secure way to access network resources over an established ssh connection. 

### Understanding SSH Tunnels

SSH tunnels create encrypted channels between your local machine and remote servers. Tunnels provide a secure transport to resources which are not otherwise directly available to a host. When used with gmount, they allow you to:

- Access shares behind firewalls or bastion hosts
- Provide an encrypted connection for the data while in transit
- Provde additional authentication using ssh

### SSH Configuration Example

Add these lines to your SSH configuration file (typically `~/.ssh/config`):\n\n#### SMB over SSH

The configuration below tells `ssh` how to handle a connection to the host `mybastion`. To intiate the connection you would enter `ssh mybastion`. The ssh application will lookup the host in the config file and apply the configured items to the connection automatically, such as using port 2222 instead of the default port 22. This allows for a much simpler command line leaving all the configuration complexity in the config file.

Otherwise, your ssh command might look something like this:
`ssh mybastion.myorg.edu -p 22222 -L 4451:files.myhost.edut:445 -L 4452:data.myhost.edu:445 -L backups.myhost.edu:445`

`LocalForward` is a keyword that tells ssh to claim a port to use locally (must not be in current use) and forward all traffic received on that port, through the secure SSH tunnel, to the specified remote host and port. After establishing the ssh connection, you can access the remote server over the configured tunnel port. In the case below, this would be `localhost:4451` <> `files.myhost.edu:445`

```bash
Host mybastion
  Hostname mybastion.myorg.edu
  Port 2222
  LocalForward 4451   files.myhost.edu:445      <-- local port 4451 will forward all traffic to files.myhost.edu on destination port 445
  LocalForward 4452   data.myhost.edu:445       <-- local port 4452 will do the same for data.myhost.edu
  LocalForward 4453   backups.myhost.edu:445    <-- local port 4453 for backups.myhost.edu
```

Each line creates a separate tunnel to a remote server (from the perspective of the bastion host):
- Listens on a local port (4451, 4452, 4453)
- Forwards traffic to the specified remote server and port (445)
- Encrypts all traffic through the SSH connection

After establishing the initial ssh connection, the tunnels will be connected to the remote serviers automatically. It's OK if the hostnames in the ssh tunnel configuration are not resolvable from your device. ssh will use the bastion host's DNS resolovers, after connecting, to find the appropriate hosts to tunnel to. If the DNS hostname is not resolvable, the connection will fail. In this cirucumstance, the IP address may be substituted for the hostname.  If the connection still fails, more investigation will be needed in terms of network or remote host routes, firewalls, access controls, etc.

The initial ssh connection will need to remain open for the tunnels to stay active. Some organizations will restrict access to only the tunnel connections so a terminal session may not be available and you may receive a connection error.  To connect without "logging in" try the `-N` ssh argument. This will only connect to the bastion host and attempt to intiate the tunnel connections without starting a shell/login on the bastion. The `-N` flag will not show any output about the connection so it can be difficult to determine if there are any connection problems. If you suspect issues with the connection, try adding the `-v` or `-vvv` flags along with `-N` and you will see debugging information printed about the connection in real-time.

A [diagram here](ssh-tunnel.gif) illustrates how the various parameters in the ssh connection information are applied.
- an ssh connection is established to the bastion host.
- ssh applies the tunnel configurations to connect to the remote hosts via the established ssh connection.

### GVFS Configuration with SSH Tunnels

Gmount was developed explicitly for use with ssh tunnels so the example configuration below uses locally forwarded ports as reviewed above. 
```json
{
  "mounts": {
    "gvfs": [
      {
        "comment": "remote files from host blah"                  # free-form comment
        "host"   : "localhost:4451",                              # hostname or a localhost tunnel and port
        "share"  : "share_name",                                  # the name of the windows share to mount
        "local"  : "/home/@USERNAME/mounts/share",                # where the symlink to the mount will be created*
        "domain" : "YOURDOMAIN"                                   # the windows Active Directory domain to use
      }
    ]
  }
}

* GFVS mounts everything under /var/run/user/$UID/gvfs and is not configurable
```

## Mounting S3 Buckets with Rclone

If you install `rclone`, you can configure a second backend in gmount for an s3 bucket. First, configure rclone for the aws account containing the bucket you want to use. Then, add that gclone reference to the `gmount.json` file. An example config may now be extended for s3 to look something like:
```json
{
  "mounts": {
    "gvfs": [
      {
        "comment": "remote files from host blah"
        "host"   : "localhost:4451",
        "share"  : "share_name",
        "local"  : "/home/@USERNAME/mounts/share",
        "domain" : "YOURDOMAIN"
      }
    ],
    "s3": [
      {         
        "comment": "S3 293 bucket",                               # free-form comment
        "backend": "rclone",                                      # default is rclone. maybe something else in the future
        "config" : "/home/@USERNAME/.config/rclone/rclone.conf",  # where to find the rclone config for this bucket
        "local"  : "/home/@USERNAME/mnt/my-bucket-0382",          # where the bucket will be mounted
        "remote" : "acloud:/my-bucket-0382"                       # the rclone config block name and literal bucket name to mount
      }
    ]
  }
}
```

### Rclone Authentication Configuration

The associated rclone configuration block below was configured for `env_auth`. This means rclone will expect to find the needed AWS connection information exported to the environment. Prior to running gmount with an S3 configuration, you will need to export `AWS_ACCESS_KEY_ID`, `AWS_REGION` and `AWS_SECRET_ACCESS_KEY` to your environment.  Other authentication methods exist in rclone if this one is not suitable but be aware that saving AWS credentials to a file may pose a substantial security risk to your org.
```
[acloud]
type      = s3
provider  = AWS
env_auth  = true
region    = us-east-2
acl       = private
server_side_encryption = AES256
```


## Mounting Windows Shares Using the CIFS Backend

The `cifs` backend allows you to mount Windows shares directly using the CIFS/SMB protocol. This is particularly useful when:
- GVFS cannot mount certain share types (e.g., user home directories)
- You need more control over mount options
- You want direct kernel-level mounts for better performance

## CIFS Backend Features

- Direct kernel-level CIFS/SMB mounting using `mount.cifs`
- Secure credential handling via temporary files in `/run/user/$UID/`
- Support for custom mount options (file permissions, versions, etc.)
- Automatic credential cleanup after mounting
- Exact mount point matching to prevent false positives
- Port specification support for non-standard SMB ports

## Security Configuration

Mounting via CIFS requires root access. Configure sudo to allow mount operations:

### Example sudoers Configuration

Create a file `/etc/sudoers.d/mount-fs` with the following content (allows `user101` to mount without password prompt):
```
{
  "mounts": {
    "gvfs": [
      {
        "comment": "remote files from host blah"
        "host"   : "localhost:4451",
        "share"  : "share_name",
        "local"  : "/home/@USERNAME/mounts/share",
        "domain" : "YOURDOMAIN"
      }
    ],
    "s3": [
      {         
        "comment": "S3 293 bucket",                               # free-form comment
        "backend": "rclone",                                      # default is rclone. maybe something else in the future
        "config" : "/home/@USERNAME/.config/rclone/rclone.conf",  # where to find the rclone config for this bucket
        "local"  : "/home/@USERNAME/mnt/my-bucket-0382",          # where the bucket will be mounted
        "remote" : "acloud:/my-bucket-0382"                       # the rclone config block name and literal bucket name to mount
      }
    ],
    "cifs": [
      {
        "comment": "Windows file server share",
        "host"   : "fileserver",
        "share"  : "projects",
        "local"  : "/home/@USERNAME/mnt/projects",
        "domain" : "MYDOMAIN",
        "options": "username=@USERNAME,rw,uid=@USER_UID,gid=@USER_GID,file_mode=0644,dir_mode=0755,vers=3.0"
      }
    ]
  }
}
```

### Example sudoers Configuration

Create a file `/etc/sudoers.d/mount-fs` with the following content (allows `user101` to mount without password prompt):

```bash
user101 ALL=(ALL:ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /sbin/mount.cifs
```

**Security Notes:**
- This gives `user101` elevated access to mount/unmount ANY filesystem on the host
- For production systems, consider more restrictive sudo configurations
- Remove `NOPASSWD` to require password entry for additional security
- Alternative: Create helper scripts with limited scope and only allow those

### CIFS Configuration with All Backends

Full example showing GVFS, S3, and CIFS backends together:

## Important Notes & Best Practices

### SSH Tunnels
- Establish SSH connections before mounting shares
- Use matching port numbers in both SSH and gmount configurations
- SSH login/tunnel must remain active for the duration of the mount
- Consider using `ssh -N` for tunnel-only connections (no shell session)
- Use `ssh -Nv` or `ssh -Nvvv` for debugging tunnel connection issues

### Data Safety
- **Save often and backup regularly**: Network disruption of mounted filesystems can lead to data corruption or loss
- Test mount configurations before relying on them for critical data
- Monitor SSH tunnel stability for tunnel-based mounts

### CIFS Backend Security
- Credentials are stored in temporary files under `/run/user/$UID/` during mount operations
- Temporary credential files are automatically deleted after mounting
- Files are created with restricted permissions (only readable by the user)
- Password never appears in process lists or command history

### Mount Point Management
- Mount points must not exist or must be empty directories before mounting
- GVFS creates symlinks to actual mounts under `/var/run/user/$UID/gvfs/`
- CIFS and S3 backends create actual mount points at the specified paths
- Exact mount path matching prevents accidental operations on similarly-named mounts

### Example Configuration

Here's a comprehensive example showing all three backends together:

```json
{
  "mounts": {
    "gvfs": [
      {
        "comment": "Direct network share",
        "host"  : "fileserver.ad.mydomain.com",
        "share" : "/users",
        "local" : "/home/@USERNAME/mounts/users",
        "domain": "WORKGROUP"
      },
      {
        "comment": "Home NAS media share",
        "host"  : "nas.home.network",
        "share" : "/media",
        "local" : "/home/@USERNAME/mounts/media",
        "domain": "MYDOMAIN"
      },
      {
        "comment": "SSH tunnel to remote share",
        "host"  : "localhost:4451",
        "share" : "data",
        "local" : "/home/@USERNAME/mounts/data",
        "domain": "MYDOMAIN"
      }
    ],
    "cifs": [
      {
        "comment": "Windows file server share (when GVFS doesn't work)",
        "host"   : "fileserver.company.com",
        "share"  : "/projects",
        "local"  : "/home/@USERNAME/mnt/projects",
        "domain" : "MYDOMAIN",
        "options": "username=@USERNAME,rw,uid=@USER_UID,gid=@USER_GID,file_mode=0644,dir_mode=0755,vers=3.0"
      },
      {
        "comment": "User home directory via SSH tunnel",
        "host"   : "localhost:4452",
        "share"  : "/home_users",
        "local"  : "/home/@USERNAME/mnt/remote-home",
        "domain" : "WORKGROUP",
        "options": "username=@USERNAME,uid=@USER_UID,gid=@USER_GID,vers=2.1"
      }
    ],
    "s3": [
      {
        "comment": "AWS S3 bucket for project data",
        "backend": "rclone",
        "config" : "/home/@USERNAME/.config/rclone/rclone.conf",
        "local"  : "/home/@USERNAME/mnt/my-bucket-0382",
        "remote" : "acloud:/my-bucket-0382"
      }
    ]
  }
}
```

### Single Backend Examples

**GVFS Only:**
```json
{
  "mounts": {
    "gvfs": [
      {
        "host"  : "fileserver.ad.mydomain.com",
        "share" : "/users",
        "local" : "/home/@USERNAME/mounts/users",
        "domain": "WORKGROUP"
      }
    ]
  }
}
```

**CIFS Only:**
```json
{
  "mounts": {
    "cifs": [
      {
        "host"   : "fileserver",
        "share"  : "/projects",
        "local"  : "/home/@USERNAME/mnt/projects",
        "domain" : "MYDOMAIN",
        "options": "username=@USERNAME,rw,uid=@USER_UID,gid=@USER_GID,file_mode=0644,dir_mode=0755,vers=3.0"
      }
    ]
  }
}
```

**S3/Rclone Only:**
```json
{
  "mounts": {
    "s3": [
      {
        "backend": "rclone",
        "config" : "/home/@USERNAME/.config/rclone/rclone.conf",
        "local"  : "/home/@USERNAME/mnt/my-bucket",
        "remote" : "acloud:/my-bucket-0382"
      }
    ]
  }
}
```

## Usage

### Mount Shares

Mount with the default `gmount.json` in the current directory:

```bash
./gmount.py
# or use the wrapper script
./gmount-mount
```

You will be prompted for your password to authenticate with the remote server(s).

### Unmount Shares

Unmount all configured shares:

```bash
./gmount.py -u
# or
./gmount.py --umount
# or use the wrapper script
./gmount-umount
```

### Use Custom Configuration File

Specify a configuration file using the `-c` or `--config` flag:

```bash
./gmount.py --config /path/to/custom_config.json
```

Or set the `GMOUNT_CONFIG` environment variable:

```bash
export GMOUNT_CONFIG=/path/to/custom_config.json
./gmount.py
```

### Wrapper Scripts

The repository includes convenience wrapper scripts:
- `gmount-mount`: Equivalent to `gmount.py` (mount operation)
- `gmount-umount`: Equivalent to `gmount.py -u` (unmount operation)

These scripts automatically detect their purpose based on their filename.

## How It Works

1. The script loads the configuration from the specified JSON file (priority: `-c` flag > `GMOUNT_CONFIG` env var > default `gmount.json`)
2. Expands configuration variables (`@USERNAME`, `@FS_UID`, `@FS_GID`, `@USER_UID`, `@USER_GID`)
3. For each configured mount point:
   - Determines the appropriate backend (gvfs, cifs, or s3)
   - Checks if the mount already exists using exact mount point matching
   - Creates the local directory structure or symlink as needed
   - **GVFS backend**: Uses `gio mount` to connect to remote SMB shares and creates symlinks to mounts under `/run/user/$UID/gvfs`
   - **CIFS backend**: Uses `mount.cifs` with sudo to create kernel-level mounts with secure credential handling
   - **S3/Rclone backend**: Uses `rclone mount` to connect to S3 buckets with environment-based authentication
   - Handles authentication via password prompt (or exported environment vars for rclone)

### Backend Architecture

The mount manager uses a modular backend system:

- **`GVFSBackend`**: Handles GNOME Virtual File System mounts via `gio mount`
  - Mounts are placed in `/var/run/user/$UID/gvfs/` 
  - Creates symlinks from user-defined paths to actual GVFS mount points
  - Best for desktop GNOME environments

- **`CIFSBackend`**: Handles direct CIFS/SMB mounts
  - Uses `mount.cifs` with sudo privileges
  - Credentials stored temporarily in secure files under `/run/user/$UID/`
  - Supports custom mount options (permissions, SMB versions, etc.)
  - Best when GVFS doesn't work or more control is needed

- **`RcloneBackend`**: Handles S3 and other cloud storage
  - Uses `rclone mount` for FUSE-based mounting
  - Supports environment-based authentication (`env_auth`)
  - Best for cloud storage buckets

### Exact Mount Matching

Both CIFS and Rclone backends implement exact mount point matching to prevent false positives. For example:
- `/mnt/myshare` will not match `/mnt/myshare-backup`
- This prevents accidental unmounting or skipping of similarly-named mounts

## Error Handling

The script includes comprehensive error handling for common scenarios:
- Configuration file errors (missing file, invalid JSON)
- Authentication failures (wrong password, expired credentials)
- Network connectivity issues
- File permission problems
- Mount point conflicts (already mounted, not empty)
- Missing dependencies (mount.cifs, rclone, gio)
- Timeout handling for mount operations
- Specific error codes from mount.cifs:
  - Error 32: Authentication failure
  - Error 5: Permission denied
  - Error 115: Operation in progress

## Troubleshooting

### CIFS Mount Fails
- Verify sudo access is properly configured in `/etc/sudoers.d/`
- Check that `mount.cifs` is installed: `which mount.cifs`
- Ensure the share path starts with `/` (e.g., `/share_name`)
- Try specifying SMB version in options: `vers=3.0` or `vers=2.1`
- Check server accessibility: `ping fileserver`

### GVFS Mount Issues
- Verify GVFS is running: `ps aux | grep gvfs`
- Check if `gio` is available: `which gio`
- Ensure GNOME environment is active
- Some share types (user home directories) may not work with GVFS - use CIFS backend instead

### SSH Tunnel Problems
- Test SSH connection independently: `ssh -v hostname`
- Verify tunnel ports are not in use: `netstat -tuln | grep 4451`
- Check SSH config file syntax: `~/.ssh/config`
- Use `ssh -Nvvv` for detailed tunnel debugging
- Confirm remote server DNS is resolvable from bastion host

### S3/Rclone Issues
- Verify rclone is installed: `which rclone`
- Test rclone connection: `rclone ls remote_name:/bucket`
- Ensure AWS credentials are exported:
  ```bash
  export AWS_ACCESS_KEY_ID=your_key
  export AWS_SECRET_ACCESS_KEY=your_secret
  export AWS_REGION=us-east-2
  ```
- Check rclone config: `rclone config show`

### Mount Point Already Exists
- Check if path is already mounted: `mount | grep /path/to/mount`
- Remove empty directories before mounting
- Use `gmount-umount` to clean up existing mounts

### Permission Denied Errors
- For CIFS: Verify sudoers configuration
- Check directory permissions for mount points
- Ensure user owns the parent directory structure


## License

This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.

This program comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions. See the GNU General Public License for more details.
