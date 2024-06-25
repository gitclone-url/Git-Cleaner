## GitCleaner

GitCleaner is a Ruby script that helps clean Git repositories by removing all commits and creating a new initial commit. It supports both GitHub repositories and Gists.


## Requirements

- Ruby 2.5 or higher
- Git

## Installation

1. Clone this repository or download the `gitcleaner.rb` file.
2. Make the script executable:

   ```
   chmod +x gitcleaner.rb
   ```

3. Install required gems:

   ```
   gem install dotenv
   ```

## Usage

You can run GitCleaner in two ways:

### 1. Using command-line arguments

```
./gitcleaner.rb --url <repository_url> --username <your_username> --password <your_password>
```

Example:
```
./gitcleaner.rb --url https://github.com/user/repo.git --username myusername --password mypassword
```

### 2. Using a .env file

Create a `.env` file in the same directory as the script with the following content:

```
GITURL=https://github.com/user/repo.git
USERNAME=your_username
PASSWORD=your_password
```

Then run the script without arguments:

```
./gitcleaner.rb
```

## License
[AGPL-3.0 license](LICENSE)
