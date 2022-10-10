#!/usr/bin/env python3

################################################
# Copyright 2021 AutraTech. All Rights Reserved.
################################################

import os
import requests

API_URL = 'https://api.github.com'
REPOS_NAME = 'autra-tech/autra_core'
GITHUB_TOKEN_PATH = os.environ['HOME'] + '/.AUTRA_GITHUB_TOKEN'


def check_response(response, is_fatal=True):
    success_code = {200, 201}
    if response.status_code not in success_code:
        print("#####################################################")
        print("Failed, response code: {}".format(response.status_code))
        print(response.text)
        print("#####################################################")
        if is_fatal:
            raise Exception


def _get_token():
    token = os.environ.get('GITHUB_TOKEN')
    if token != None:
        return token

    if not os.path.exists(GITHUB_TOKEN_PATH):
        print("You didn't register github token, please apply a github token following guide: "
              "https://bg4kuaip34.feishu.cn/wiki/wikcnb4NDFlJOCLVgSLe9bBgyqC")
        token = input('Enter token: ')
        response = requests.get(
            url='{}/repos/{}'.format(API_URL, REPOS_NAME),
            headers={"Authorization": "token {}".format(token)}
        )
        check_response(response)
        with open(GITHUB_TOKEN_PATH, 'w') as f:
            f.write(token)
        print('Github token is saved sucessfully.')
        return token

    with open(GITHUB_TOKEN_PATH, 'r') as f:
        return f.read().strip()


token = _get_token()
session = requests.sessions.Session()
session.headers.update({"Authorization": "token {}".format(token)})


def _get_url(api_name, suffix):
    return '{}/{}/{}/{}'.format(API_URL, api_name, REPOS_NAME, suffix)


def _mark_status(commit_sha, context, state, description, target_url = None):
    body = {
        'context': context,
        "state": state,
        'description': description,
    }
    if target_url != None:
        body['target_url'] = target_url
    return session.post(
        url=_get_url('repos', 'statuses/{}'.format(commit_sha)),
        json=body)


def mark_status_success(commit_sha, status_name, description, check_res = True, target_url = None):
    response = _mark_status(commit_sha, status_name, 'success', description, target_url)
    if check_res:
        check_response(response)
    return response


def mark_status_failure(commit_sha, status_name, description, check_res = True, target_url = None):
    response = _mark_status(commit_sha, status_name, 'failure', description, target_url)
    if check_res:
        check_response(response)
    return response


def create_pr(head_branch, base_branch):
    with open(os.path.join(os.path.dirname(__file__), "pull_request_content_template")) as f:
        content_template = f.read()
        body = {
            'title': head_branch,
            'head': head_branch,
            'base': base_branch,
            'body': content_template
        }
        return session.post(
            url=_get_url('repos', 'pulls'),
            json=body)


def get_pull_request(branch_name: str):
    # List all open pull requests
    response = requests.get(
        url='{}/repos/{}/pulls?state=open'.format(API_URL, REPOS_NAME),
        headers={"Authorization": "token {}".format(token)}
    )
    data = response.json()
    # Match branch_name with head's ref
    for pull_request in data:
        pull_request_head_ref = pull_request["head"]['ref']
        if pull_request_head_ref == branch_name:
            return pull_request
    return None


def get_approved_reviewers(pull_numbers):
    response = requests.get(
        url='{}/repos/{}/pulls/{}/reviews?per_page={}'.format(API_URL, REPOS_NAME, pull_numbers, 100),
        headers={"Authorization": "token {}".format(token)}
    )
    data = response.json()
    approved_reviewers = []
    for reviewer in data:
        if reviewer['state'] == 'APPROVED':
            approved_reviewers.append(reviewer['user']['login'])
    return approved_reviewers
