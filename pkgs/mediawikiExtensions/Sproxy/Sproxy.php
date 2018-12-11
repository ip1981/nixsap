<?php

// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 2 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <http://www.gnu.org/licenses/>.
//
// Copyright 2006 Otheus Shelling
// Copyright 2007 Rusty Burchfield
// Copyright 2009 James Kinsman
// Copyright 2010 Daniel Thomas
// Copyright 2010 Ian Ward Comfort
// Copyright 2013-2016 Zalora South East Asia Pte Ltd
//
// In 2009, the copyright holders determined that the original publishing of this code
// under GPLv3 was legally and logistically in error, and re-licensed it under GPLv2.
//
// See http://www.mediawiki.org/wiki/Extension:AutomaticREMOTE_USER
//
// Adapted by Rusty to be compatible with version 1.9 of MediaWiki
// Optional settings from Emmanuel Dreyfus
// Adapted by VibroAxe (James Kinsman) to be compatible with version 1.16 of MediaWiki
// Adapted by VibroAxe (James Kinsman) to allow domain substitution for Integrated Windows Authentication
// Adapted by drt24 (Daniel Thomas) to add the optional $wgAuthRemoteuserMailDomain and remove hardcoding
//   of permissions for anonymous users.
// Adapted by Ian Ward Comfort to detect mismatches between the session user and REMOTE_USER
// Adapted to sproxy by Chris Forno
// Extension credits that show up on Special:Version

$wgExtensionCredits['other'][] = array(
  'name' => 'Sproxy',
  'version' => '0.2.0',
  'author' => array(
    'Otheus Shelling',
    'Rusty Burchfield',
    'James Kinsman',
    'Daniel Thomas',
    'Ian Ward Comfort',
    'Chris Forno'
  ) ,
  'url' => '',
  'description' => 'Automatically authenticates users using sproxy HTTP headers.',
);

// We must allow zero length passwords. This extension does not work in MW 1.16 without this.
$wgMinimalPasswordLength = 0;

function sproxy_hook()
{
  global $wgUser, $wgRequest, $wgAuth;

  // For a few special pages, don't do anything.
  $skipPages = array(
    Title::makeName(NS_SPECIAL, 'UserLogin') ,
    Title::makeName(NS_SPECIAL, 'UserLogout') ,
  );

  if (in_array($wgRequest->getVal('title') , $skipPages)) {
    return;
  }

  // Don't do anything if there's already a valid session.
  $user = User::newFromSession();
  if (!$user->isAnon()) {
    return;
  }

  // If the login form returns NEED_TOKEN try once more with the right token
  $trycount = 0;
  $token = '';
  $errormessage = '';
  do {
    $tryagain = false;
    // Submit a fake login form to authenticate the user.
    $params = new FauxRequest(array(
      'wpName' => sproxy_username() ,
      'wpPassword' => '',
      'wpDomain' => '',
      'wpLoginToken' => $token,
      'wpRemember' => '',
    ));
    // Authenticate user data will automatically create new users.
    $loginForm = new LoginForm($params);
    $result = $loginForm->authenticateUserData();
    switch ($result) {
    case LoginForm::SUCCESS:
      $wgUser->setOption('rememberpassword', 1);
      $wgUser->setCookies();
      break;

    case LoginForm::NEED_TOKEN:
      $token = $loginForm->getLoginToken();
      $tryagain = ($trycount == 0);
      break;

    default:
      error_log("Unexpected sproxy authentication failure (code: $result)");
      break;
    }
    $trycount++;
  }
  while ($tryagain);
}

$wgExtensionFunctions[] = 'sproxy_hook';
function sproxy_email()
{
  return $_SERVER['HTTP_FROM'];
}

function sproxy_username()
{
  return sproxy_email();
}

function sproxy_real_name()
{
  return $_SERVER['HTTP_X_GIVEN_NAME'] . ' ' . $_SERVER['HTTP_X_FAMILY_NAME'];
}

class AuthSproxy extends AuthPlugin
{
  public function userExists($username)
  {
    // This does not mean does the user already exist in the Mediawiki database.
    return true;
  }

  public function authenticate($username, $password)
  {
    // All users are already authenticated.
    return true;
  }

  public function autoCreate()
  {
    // Automatically create Mediawiki users for sproxy users.
    return true;
  }

  function allowPasswordChange()
  {
    // This doesn't make any sense so don't allow it.
    return false;
  }

  public function strict()
  {
    // Don't check passwords against the Mediawiki database;
    return true;
  }

  public function initUser(&$user, $autocreate = false)
  {
    $user->setEmail(sproxy_email());
    $user->mEmailAuthenticated = wfTimestampNow();
    $user->setToken();
    $user->setRealName(sproxy_real_name());

    // turn on e-mail notifications
    if (isset($wgAuthRemoteuserNotify) && $wgAuthRemoteuserNotify) {
      $user->setOption('enotifwatchlistpages', 1);
      $user->setOption('enotifusertalkpages', 1);
      $user->setOption('enotifminoredits', 1);
      $user->setOption('enotifrevealaddr', 1);
    }
    $user->saveSettings();
  }
}

$wgAuth = new AuthSproxy();

// Don't let anonymous people do things...
$wgGroupPermissions['*']['createaccount'] = false;
$wgGroupPermissions['*']['read'] = false;
$wgGroupPermissions['*']['edit'] = false;

// see http://www.mediawiki.org/wiki/Manual:Hooks/SpecialPage_initList
// and http://www.mediawiki.org/w/Manual:Special_pages
// and http://lists.wikimedia.org/pipermail/mediawiki-l/2009-June/031231.html
// disable login and logout functions for all users
function LessSpecialPages(&$list)
{
  unset($list['ChangeEmail']);
  unset($list['Userlogin']);
  unset($list['Userlogout']);
  return true;
}
$wgHooks['SpecialPage_initList'][] = 'LessSpecialPages';

// http://www.mediawiki.org/wiki/Extension:Windows_NTLM_LDAP_Auto_Auth
// remove login and logout buttons for all users
function StripLogin(&$personal_urls, &$wgTitle)
{
  unset($personal_urls["login"]);
  unset($personal_urls["logout"]);
  unset($personal_urls['anonlogin']);
  return true;
}
$wgHooks['PersonalUrls'][] = 'StripLogin';

