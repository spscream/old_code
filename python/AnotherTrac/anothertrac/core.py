# -*- coding: utf8 -*-
"""
AnotherTrac:
a plugin for Trac
http://trac.edgewall.org
"""

import	re


from trac.core import *
from trac import util
from trac.util.text import to_unicode
from trac.env import Environment
from trac.ticket.model import Ticket
from trac.ticket.notification import TicketNotifyEmail

from trac.ticket.api import ITicketChangeListener

from datetime import tzinfo, timedelta, datetime

class UTC(tzinfo):
        """UTC"""
        ZERO = timedelta(0)
        HOUR = timedelta(hours=1)

        def utcoffset(self, dt):
                return self.ZERO

        def tzname(self, dt):
                return "UTC"

        def dst(self, dt):
                return self.ZERO


class AnotherTracCore(Component):

    implements(ITicketChangeListener)

    ### methods for ITicketChangeListener

    """Extension point interface for components that require notification
    when tickets are created, modified, or deleted."""
    
    def ticket_changed(self, ticket, comment, author, old_values):
        """Called when a ticket is modified.
        
        `old_values` is a dictionary containing the previous values of the
        fields that have changed.
        """
	self.log.info("DEBUG: ticket_changed(ticket, comment, author, old_values")
        self.log.info("DEBUG: owner: %s" %ticket['owner'])
        self.log.info("DEBUG: %s" %comment)
        self.log.info("DEBUG: %s" %author)
        self.log.info("DEBUG: %s" %old_values)
        self.log.info("DEBUG: %s" %ticket['anothertrac'])
	another_tracs = self._get_another_tracs()
        self.log.info("Another tracs dict: %s" %another_tracs)

	tkt_id = ticket.id
        
	# Check for [another-tracs] config section
        if another_tracs:
            for trac in another_tracs:
		env = None
		env = Environment(trac['path'])

		another_tkt_id = self.another_ticket_exist(self.env,tkt_id)
		
		# Check if ticket is "another".
		if ticket['reporter'] == trac['user']:
		    self.log.info("MATCH reporter!!! RAAAAAGHHHHH")
		    if another_tkt_id:
			self.change_another_ticket(env, another_tkt_id, comment, author, ticket, trac, 'native')
		    return True    
                # Check if ticket is "native".
		elif ticket['owner'] == trac['user']:
                    self.log.info("MATCH owner!!! ARGHHHHHHHHH")
		    if not another_tkt_id:
			self.log.info("NATIVE_TICKET: new_another_ticket(%s)" %tkt_id)
			another_tkt_id = self.new_another_ticket(env, ticket, comment, author, trac)
			if another_tkt_id:
			    self.log.info("NATIVE_TICKET: new ticket in another trac success created, id: %s" %another_tkt_id)
			    self._insert_anotherticket(self.env, tkt_id, trac['name'], another_tkt_id)
			else:
			    self.log.warning("NATIVE_TICKET: fail during create ticket in another trac")
		    else:
			    self.log.info("ANOTHER TICKET EXIST!!!")
			    self.change_another_ticket(env, another_tkt_id, comment, author, ticket, trac)
		    return True
                	
			
    def ticket_created(self, ticket):
        """Called when a ticket is created."""

    def ticket_deleted(self, ticket):
        """Called when a ticket is deleted."""
	self.log.info("AnotherTrac::ticket_deleted")
	self.another_ticket_delete(self.env, ticket)

    def new_another_ticket(self, env, ticket, comment, author, trac):
	project_name = self.env.config.get('project','name')
	project_url = self.env.config.get('project','url')
	tkt_id = ticket.id
	tkt = Ticket(env)
	
	self.log.info("Ticket_id: %s" %(ticket.id))
                    
	tkt['status'] = 'new'
        tkt['reporter'] = project_name
        tkt['summary'] = '[' + project_name + '] #'+ str(tkt_id) +": "+ ticket['summary']
	
	description = ticket['description']
	if not comment == "":
	    comment = "\n * Comment: \n" + comment + "\n"
	ticket_url = "\n * Ticket: " + "[" + project_url + "/ticket/" + str(tkt_id) + " "  + project_name + "]"
	
        tkt['description'] = description + comment + ticket_url
	
	if ticket['taskstatus']:
	    tkt['taskstatus'] = trac['newstatus']
	
        self.log.info("tkt.insert")
	another_tkt_id = tkt.insert()
	if another_tkt_id:
	    self._insert_anotherticket(env, another_tkt_id, project_name, tkt_id)
	    self.notify(env, tkt, True)
	    return another_tkt_id
	else:
	    return False
	    
    def	change_another_ticket(self, env, tkt_id, comment, author, ticket, trac, action='another'):
	""" Change ticket in another_trac """
	self.log.info("Call change_another_ticket(%s)" %(tkt_id))
	another_proj_name = env.config.get('project','name')
	if not re.match(".* \["+ another_proj_name +"\]", author):
	    (db,cursor) = self._get_dbcursor(env)
	    utc = UTC()
	    when = datetime.now(utc)
	    project_name = self.env.config.get('project','name')
	
	    try:
		tkt = Ticket(env, tkt_id, db)
	    except util.TracError, detail:
		return False	    
	
	    if action == 'native':
		if 'closed' in ticket['status']:
		    cursor.execute("SELECT oldvalue,author FROM ticket_change WHERE ticket='"+tkt_id+"' AND field = 'owner' ORDER by time DESC LIMIT 1")
		    old_owner = cursor.fetchone()[0]
#		    tkt['owner'] = old_owner
		    tkt['owner'] = tkt['reporter']
		    if tkt['taskstatus']:
			tkt['taskstatus'] = trac['returnstatus']
		    
	
	    elif action == 'another':
		if 'closed' in tkt['status'] and 'closed' not in ticket['status']:
		    self.log.info("TICKET FIXED AND CLOSED! REOPEN IT!")
		    tkt['status'] = 'reopened'
		    tkt['resolution'] = ''
	
	    author = author + " [" + project_name + "]"
	    tkt.save_changes(author, comment, when)
	    self.notify(env, tkt, False, when)
	    return True
	else:
	    self.log.info("DUP!")
	    return True
	
    def another_ticket_exist(self, env, tkt_id):
	""" Check if ticket already exists in another_trac """
	
	(db,cursor) = self._get_dbcursor(env)
	cursor.execute("SELECT another_trac,another_ticket FROM anothertrac_tickets WHERE ticket = %s" %tkt_id)
	try: 
	    (another_trac_name,another_tkt_id) = cursor.fetchone()
	    return another_tkt_id
	except TypeError, detail:
	    self.log.info("Another ticket does not exist, create new one")
	    return False
    
    def another_ticket_delete(self, env, ticket):
	""" Calls when ticket_deleted() """
	(db,cursor) = self._get_dbcursor(env)
	tkt_id = ticket.id
	sql = "DELETE FROM anothertrac_tickets WHERE ticket='%s';" %tkt_id
	self.log.info(sql)
	cursor.execute(sql)
	db.commit()
	return True

    def notify(self, env, tkt, new=True, modtime=0):
	""" A Wrapper for TRAC notify function """
        try:
            # create false {abs_}href properties, to trick Notify()
            #
    	    tn = TicketNotifyEmail(env)
            tn.notify(tkt, new, modtime)
        except Exception, e:
            print 'TD: Failure sending notification on creation of ticket #%s: %s' %(tkt['id'], e)
    
    # self methods
    def _get_another_tracs(self):
        tracs = []
        config = self.config['another-trac']
        for name in [option for option,value in config.options()
                     if '.' not in option]:
            trac = {
                'name' : name,
                'path' : config.get(name),
                'user' : config.get(name + '.user'),
		'newstatus' : config.get(name + '.newstatus'),
		'returnstatus' : config.get(name + '.returnstatus')
            }
            tracs.append(trac)
        return tracs
	    
    def _insert_anotherticket(self,env,ticket,another_trac,another_ticket):
	''' Insert Into anothertrac_tickets (ticket|another_trac|another_ticket) '''
	(db,cursor) = self._get_dbcursor(env)
	cursor.execute("INSERT INTO anothertrac_tickets "
			"VALUES (%s, %s, %s)", (ticket,
			another_trac,another_ticket) )
    	db.commit()
	return True
    
    def _get_dbcursor(self,env):
	db = env.get_db_cnx()
	cursor = db.cursor()
	return db,cursor
