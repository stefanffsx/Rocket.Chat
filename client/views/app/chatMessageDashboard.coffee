Template.chatMessageDashboard.helpers
	own: ->
		return 'own' if this.data.u?._id is Meteor.userId()

	username: ->
		return this.u.username

	messageDate: (date) ->
		return moment(date).format('LL')

	isSystemMessage: ->
		return this.t in ['s', 'p', 'f', 'r', 'au', 'ru', 'ul', 'nu', 'wm']

	isEditing: ->
		return this._id is Session.get('editingMessageId')

	preProcessingMessage: ->
		msg = this.msg

		# Separate text in code blocks and non code blocks
		msgParts = msg.split(/(```.*\n[\s\S]*?\n```)/)

		for part, index in msgParts
			# Verify if this part is code
			codeMatch = part.match(/```(.*)\n([\s\S]*?)\n```/)
			if codeMatch?
				# Process highlight if this part is code
				lang = codeMatch[1]
				code = codeMatch[2]
				if lang not in hljs.listLanguages()
					result = hljs.highlightAuto code
				else
					result = hljs.highlight lang, code
				msgParts[index] = "<pre><code class='hljs " + result.language + "'>" + result.value + "</code></pre>"
			else
				# Escape html and fix line breaks for non code blocks
				part = _.escapeHTML part
				part = part.replace /\n/g, '<br/>'
				msgParts[index] = part

		# Re-mount message
		msg = msgParts.join('')

		# Process links in message
		msg = Autolinker.link(msg, { stripPrefix: false, twitter: false })

		# Process MD like for strong, italic and strike
		msg = msg.replace(/\*([^*]+)\*/g, '<strong>$1</strong>')
		msg = msg.replace(/\_([^_]+)\_/g, '<i>$1</i>')
		msg = msg.replace(/\~([^_]+)\~/g, '<strike>$1</strike>')

		# Highlight mentions
		if not this.mentions? or this.mentions.length is 0
			mentions = _.map this.mentions, (mention) ->
				return mention.username or mention

			mentions = mentions.join('|')
			msg = msg.replace new RegExp("(?:^|\\s)(@(#{mentions}))(?:\\s|$)", 'g'), (match, mention, username) ->
				return match.replace mention, "<a href=\"\" class=\"mention-link\" data-username=\"#{username}\">#{mention}</a>"

		return msg

	message: ->
		if this.u._id
			UserManager.addUser(this.u._id)
		else if this.u?.username
			UserManager.addUser this.u.username
		switch this.t
			when 'p' then "<i class='icon-link-ext'></i><a href=\"#{this.url}\" target=\"_blank\">#{this.msg}</a>"
			when 'r' then t('chatMessageDashboard.Room_name_changed', { room_name: this.msg, user_by: Session.get('user_' + this.u._id + '_name') }) + '.'
			when 'au' then t('chatMessageDashboard.User_added_by', { user_added: this.msg, user_by: Session.get('user_' + this.u._id + '_name') })
			when 'ru' then t('chatMessageDashboard.User_removed_by', { user_removed: this.msg, user_by: Session.get('user_' + this.u._id + '_name') })
			when 'ul' then t('chatMessageDashboard.User_left', this.msg)
			when 'nu' then t('chatMessageDashboard.User_added', this.msg)
			when 'wm' then t('chatMessageDashboard.Welcome', this.msg)
			else this.msg

	time: ->
		return moment(this.ts).format('HH:mm')

	newMessage: ->
		# @TODO pode melhorar, acho que colocando as salas abertas na sessão
		# if $('#chat-window-' + this.rid + '.opened').length == 0
		# 	return 'new'

	preMD: Template 'preMD', ->
		self = this
		text = ""
		if self.templateContentBlock
			text = Blaze._toText(self.templateContentBlock, HTML.TEXTMODE.STRING)

		text = text.replace(/#/g, '\\#')
		return text

	getPupupConfig: ->
		template = Template.instance()
		return {
			getInput: ->
				return template.find('.input-message-editing')
		}

Template.chatMessageDashboard.events
	'mousedown .edit-message': ->
		self = this
		Session.set 'editingMessageId', undefined
		Meteor.defer ->
			Session.set 'editingMessageId', self._id

			Meteor.defer ->
				$('.input-message-editing').select()

	'click .mention-link': (e) ->
		Session.set('flexOpened', true)
		Session.set('showUserInfo', $(e.currentTarget).data('username'))

Template.chatMessageDashboard.onRendered ->
	chatMessages = $('.messages-box .wrapper')
	message = $(this.firstNode)

	if this.data.scroll? and message.data('scroll-to-bottom')?
		if message.data('scroll-to-bottom') and (this.parentTemplate().scrollOnBottom or this.data.data.uid is Meteor.userId())
			chatMessages.stop().animate({scrollTop: 99999}, 1000 )
		else
			# senao, exibe o alerta de mensagem  nova
			$('.new-message').removeClass('not')
	else
		if not chatMessages.data('previous-height')
			chatMessages.stop().scrollTop(99999)
		else
			chatMessages.stop().scrollTop(chatMessages.get(0).scrollHeight - chatMessages.data('previous-height'))
