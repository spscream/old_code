"""
CrowdPasswordStore:
a plugin for Trac
http://trac.edgewall.org
"""
from trac.core import *
from trac.config import Option
from httplib import HTTPConnection
from urlparse import urlparse, urlunparse

import crypt
import md5
import sha
import base64
import time
import amara

from acct_mgr.api import IPasswordStore
from trac.perm import IPermissionGroupProvider
from trac.perm import IPermissionStore
from tracusermanager.api import UserManager, User

from crowd_lib import Crowd


class CrowdPasswordStore(Component):
    implements(IPasswordStore)

    def __init__(self):
        self.crowd_server = self.config.get('crowd', 'server')
        self.crowd_port = self.config.getint('crowd', 'port')
        self.crowd_appname = self.config.get('crowd', 'appname')
        self.crowd_apppass = self.config.get('crowd', 'apppass')
        self.crowd = Crowd('http://jira:8095', self.crowd_appname,
                                                self.crowd_apppass, 60)
        self.crowd_usertoken = None
        self.enabled = True

        self._cache = {}
        self._cache_ttl = int(self.config.get('crowd',
                                              'cache_ttl', str(15*60)))
        self._cache_size = min(25, int(self.config.get('ldap',
                                              'cache_size', '100')))

    ### IPasswordStore methods

    def config_key(self):
        """
        '''Deprecated''':
        new implementations of this interface are not required
        to implement this method, since the prefered way to configure the
        `IPasswordStore` implemenation is by using its class name in
        the `password_store` option.

        Returns a string used to identify this implementation in the config.
        This password storage implementation will be used if the value of
        the config property "account-manager.password_format" matches.
        """

    def get_users(self):
        """ Returns an iterable of the known usernames  """
        #users = self._crowd_userlist()
        current_time = time.time()

        if 'users' in self._cache:
            lut, users = self._cache['users']
            if current_time < lut+self._cache_ttl:
                # sources the cache
                # cache lut is not updated to ensure
                # it is refreshed on a regular basis
                self.env.log.debug('cached : %s' % \
                                   (','.join(users)))
                return users

        # cache miss (either not found or too old)
        users = self.crowd.userlist()
        # if some users is found
        if users:
        # tests for cache size
            if len(self._cache) >= self._cache_size:
                # the cache is becoming too large, discards
                # the less recently uses entries
                cache_keys = self._cache.keys()
                cache_keys.sort(lambda x, y: cmp(self._cache[x][0],
                                                self._cache[y][0]))
                # discards the 5% oldest
                old_keys = cache_keys[:(5*self._cache_size)/100]
                for k in old_keys:
                    del self._cache[k]
            else:
            # deletes the cache if there's no group for this user
            # for debug, until a failed LDAP connection returns an error...
                if username in self._cache:
                    del self._cache['users']

        self._cache['users'] = [current_time, users]
        #self.env.log.info("[DEBUG] Crowd userlist: %s"%users)
        return users

    def has_user(self, user):
        """Returns whether the user account exists.
        """
        #self.env.log.info("checking user: %s"%user)
        return user in self.get_users()

    def set_password(self, user, password):
        """Sets the password for the user.  This should create the user account
        if it doesn't already exist.
        Returns True if a new account was created, False if an existing account
        was updated.
        """

    def check_password(self, user, password):
        """Checks if the password is valid for the user.
        """
        print "CROWD DEBUG check_password(user,password): %s,%s" \
                 %(user, password)
        try:
            token = self.crowd.auth(user, password)
            return True
        except Exception, e:
            self.env.log.info('Got exception %s', e)
            return False

    def delete_user(self, user):
        """Deletes the user account.
        Returns True if the account existed and was deleted, False otherwise.
        """


class CrowdPermissionGroupProvider(Component):
    implements(IPermissionGroupProvider)

    def __init__(self):
        """ init method """
        self.crowd_server = self.config.get('crowd', 'server')
        self.crowd_port = self.config.getint('crowd', 'port')
        self.crowd_appname = self.config.get('crowd', 'appname')
        self.crowd_apppass = self.config.get('crowd', 'apppass')
        self.crowd = Crowd('http://jira:8095', self.crowd_appname,
                                            self.crowd_apppass, 60)
        self.crowd_usertoken = None
        self.enabled = True

        # user entry local cache
        self._cache = {}
        self._cache_ttl = int(self.config.get('crowd',
                                            'cache_ttl', str(15*60)))
        self._cache_size = min(25,
                            int(self.config.get('ldap', 'cache_size', '100')))

    ### IPermissionGroupProvider methods

    def get_permission_groups(self, username):
        """
        Return a list of names of the groups that the user with the specified
        name is a member of.
        """
        groups = []
        if not self.enabled:
            return groups

        # stores the current time for the request (used for the cache)
        current_time = time.time()


        # test for if username in the cache
        if username in self._cache:
            # cache hit
            lut, groups = self._cache[username]

            # ensures that the cache is not too old
            if current_time < lut+self._cache_ttl:
                # sources the cache
                # cache lut is not updated to ensure
                # it is refreshed on a regular basis
                self.env.log.debug('cached (%s): %s' % \
                                   (username, ','.join(groups)))
                return groups

        self.env.log.info("get_permission_groups(): %s]"%(username))
        crowdgroups = self.crowd.user_groups(username)
        if crowdgroups:
            # tests for cache size
            if len(self._cache) >= self._cache_size:
                # the cache is becoming too large, discards
                # the less recently uses entries
                cache_keys = self._cache.keys()
                cache_keys.sort(lambda x, y: cmp(self._cache[x][0],
                                                self._cache[y][0]))
                # discards the 5% oldest
                old_keys = cache_keys[:(5*self._cache_size)/100]
                for k in old_keys:
                    del self._cache[k]
        else:
            # deletes the cache if there's no group for this user
            # for debug, until a failed LDAP connection returns an error...
            if username in self._cache:
                del self._cache[username]

        # updates the cache
        self._cache[username] = [current_time, crowdgroups]

        # returns the user groups
        groups.extend(crowdgroups)
        if groups:
            self.env.log.debug('groups: ' + ','.join(groups))

        return groups

    def flush_cache(self, username=None):
        """Invalidate the entire cache or a named entry"""
        if username is None:
            self._cache = {}
        elif username in self._cache:
            del self._cache[username]


class CrowdPermissionStore(Component):

    implements(IPermissionStore)

    group_providers = ExtensionPoint(IPermissionGroupProvider)

    def __init__(self):
        """ init method """
        self.crowd_server = self.config.get('crowd', 'server')
        self.crowd_port = self.config.getint('crowd', 'port')
        self.crowd_appname = self.config.get('crowd', 'appname')
        self.crowd_apppass = self.config.get('crowd', 'apppass')
        self.crowd = Crowd('http://jira:8095', self.crowd_appname,
                                            self.crowd_apppass, 60)
        self.crowd_usertoken = None
        self.enabled = True

        self._cache = {}
        self._cache_ttl = int(self.config.get('crowd',
                                            'cache_ttl', str(15*60)))
        self._cache_size = min(25,
                            int(self.config.get('ldap', 'cache_size', '100')))


    ### Methods for IPermissionStore

    """Extension point interface for components that provide storage and
    management of permissions."""

    def get_all_permissions(self):
        """Return all permissions for all users.

        The permissions are returned as a list of (subject, action)
        formatted tuples."""
        self.env.log.info("!!!!!!GET ALL PERMISSIONS!!!!!!")
        actions = []
        users = self.crowd.userlist()
        for user in users:
            for group in self.crowd.user_groups(user):
                actions.append((user, group))
        """ Retrieves default permissions from trac """

        db = self.env.get_db_cnx()
        cursor = db.cursor()
        cursor.execute("SELECT username,action FROM permission")
        for row in cursor:
            actions.append((row[0], row[1]))

        return actions

    def get_user_permissions(self, username):
        """Return all permissions for the user with the specified name.

        The permissions are returned as a dictionary where the key is the name
        of the permission, and the value is either `True` for granted
        permissions or `False` for explicitly denied permissions."""
        self.env.log.info("!!!!!!USER PERMISSION GET!!!!!")

        if not self.enabled:
            raise TracError("CrowdPermissionStore is not enabled")
        actions = self._get_cache_actions(username)
        if not actions:
            subjects = set([username])
            for provider in self.group_providers:
                subjects.update(provider.get_permission_groups(username))

            actions = set([])
            db = self.env.get_db_cnx()
            cursor = db.cursor()
            cursor.execute("SELECT username,action FROM permission")
            rows = cursor.fetchall()
            while True:
                num_users = len(subjects)
                num_actions = len(actions)
                for user, action in rows:
                    if user in subjects:
                        if action.isupper() and action not in actions:
                            actions.add(action)
                        if not action.isupper() and action not in subjects:
                            # action is actually the name
                            # of the permission group here
                            subjects.add(action)
                if num_users == len(subjects) and num_actions == len(actions):
                    break
            self.env.log.debug('new: %s' % actions)
            self._update_cache_actions(username, actions)

        #FIXME
        self.fill_user_details(username)
        perms = {}
        for action in actions:
            perms[action] = True
        return perms

    def get_users_with_permissions(self, permissions):
        """Retrieve a list of users that have any of the specified permissions.

        Users are returned as a list of usernames.
        """
        self.env.log.info("!!!!!GET USER WITH PERMISSIONS!!!!!")
        db = self.env.get_db_cnx()
        cursor = db.cursor()
        result = set()
        users = set([u[0] for u in self.env.get_known_users()])
        for user in users:
            userperms = self.get_user_permissions(user)
            for group in permissions:
                if group in userperms:
                    result.add(user)
        return list(result)

    def grant_permission(self, username, action):
        """Grants a user the permission to perform the specified action."""
        db = self.env.get_db_cnx()
        cursor = db.cursor()
        cursor.execute("INSERT INTO permission VALUES (%s, %s)",
                       (username, action))
        self.log.info('Granted permission for %s to %s' % (action, username))
        db.commit()

    def revoke_permission(self, username, action):
        """Revokes a users' permission to perform the specified action."""
        if not self.enabled:
            raise TracError("CrowdPermissionStore is not enabled")

        db = self.env.get_db_cnx()
        cursor = db.cursor()
        cursor.execute("DELETE FROM permission WHERE username=%s \
                        AND action=%s",
                        (username, action))
        self.log.info('Revoked permission for %s to %s' % (action, username))
        db.commit()
        self.flush_cache(username)
        self._del_cache_actions(username, [action])

    def fill_user_details(self, username):
        """ Retrieves the user details from crowd
        and fills in session_attribute table
        """
        user = UserManager(self.env).get_user(username)
        if not user['email'] or not user['name']:
            details = self.crowd.user_details(username)
            for detail in details:
                if detail.name == 'mail':
                    user['email'] = detail.values[0]
                    self.env.log.info(detail.values)
                if detail.name == 'sn':
                    user['name'] = detail.values[0]
                if detail.name == 'givenName':
                    user['name'] += " "+detail.values[0]
            user.save()

    def _get_cache_actions(self, username):
        """Retrieves the user permissions from the cache, if any"""
        if username in self._cache:
            lut, actions = self._cache[username]
            if time.time() < lut+self._cache_ttl:
                self.env.log.debug('cached (%s): %s' % \
                                   (username, ','.join(actions)))
                return actions
        return []

    def _add_cache_actions(self, username, newactions):
        """Add new user actions into the cache"""
        self._cleanup_cache()
        if username in self._cache:
            lut, actions = self._cache[username]
            for action in newactions:
                if action not in actions:
                    actions.append(action)
            self._cache[username] = [time.time(), actions]
        else:
            self._cache[username] = [time.time(), newactions]

    def _del_cache_actions(self, username, delactions):
        """Remove user actions from the cache"""
        if not username in self._cache:
            return
        lut, actions = self._cache[username]
        newactions = []
        for action in actions:
            if action not in delactions:
                newactions.append(action)
        if len(newactions) == 0:
            del self._cache[username]
        else:
            self._cache[username] = [time.time(), newactions]

    def _update_cache_actions(self, username, actions):
        """Set the cache entry for the user with the new actions"""
        # if not action, delete the cache entry
        if len(actions) == 0:
            if username in self._cache:
                del self._cache[username]
            return
        #self._cleanup_cache()
        # overwrite the cache entry with the new actions
        self._cache[username] = [time.time(), actions]

    def _cleanup_cache(self):
        """Make sure the cache is not full or discard oldest entries"""
        # if cache is full, removes the LRU entries
        if len(self._cache) >= self._cache_size:
            cache_keys = self._cache.keys()
            cache_keys.sort(lambda x, y: cmp(self._cache[x][0],
                                            self._cache[y][0]))
            old_keys = cache_keys[:(5*self._cache_size)/100]
            self.log.info("flushing %d cache entries" % len(old_keys))
            for k in old_keys:
                del self._cache[k]

    def flush_cache(self, username=None):
        """Delete all entries in the cache"""
        if username is None:
            self._cache = {}
        elif username in self._cache:
            del self._cache[username]
        # we also need to flush the LDAP permission group provider
        self._flush_group_cache(username)

    def _flush_group_cache(self, username=None):
        """Flush the group cache (if in use)"""
        if self.manage_groups:
            for provider in self.group_providers:
                if isinstance(provider, CrowdPermissionGroupProvider):
                    provider.flush_cache(username)
