## Introduction

[amarprizebond/express-backend](https://github.com/amarprizebond/express-backend) is a part of AmarPrizebond project, that provides API. This is the core of the project.

## Install

Cloning the project
* Clone the project in your local machine. `git clone https://github.com/amarprizebond/express-backend.git prizebond-backend`
* Go to the project folder. `cd prizebond-backend`
* Install necessary npm packages in order to run the project. `npm install`

Configuring the `.env` file
* Create `.env` file by copying/renaming `.env.sample` file.
* Enter right DB config in `.env` file.
* If you are willing to get slack notification function to work, enter Slack hook URL in `.env` file.
* Enter either mailtrap or sendinblue config in `.env` file in order mail function to work.

Configuring Database
* Import the database using the file [`prizebond.sql`](https://github.com/amarprizebond/express-backend/blob/master/prizebond.sql).
* Enable event schedular globally. `SET @@global.event_scheduler = 'ON';`

Run the project
* `npm start` to run the project. Open `http://localhost:4000/api` url to Postman or any other your favorite API client.
* Use `npm run devstart`. This will use nodemon which is useful when you are developing the project.
* You should get a `Welcome to Express` page.

## Contribute
In order to contribute to the project, checkout project issues, https://github.com/amarprizebond/express-backend/issues and projects, https://github.com/orgs/amarprizebond/projects/4 for available tasks we have plan to implement in future. Take one task you want to work on, then open a pull request. 

You can also create an issue, and report bug or request new feature.

## Scripts
This project is build on expressjs. Available scripts are:

#### `npm start`
Runs the project.

#### `npm run devstart`
Run the project with nodemon.
