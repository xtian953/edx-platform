if Backbone?
  class @Discussion extends Backbone.Collection
    model: Thread

    initialize: (models, options={})->
      @pages = options['pages'] || 1
      @current_page = 1
      @bind "add", (item) =>
        item.discussion = @
      @comparator = @sortByDateRecentFirst
      @on "thread:remove", (thread) =>
        @remove(thread)

    find: (id) ->
      _.first @where(id: id)

    hasMorePages: ->
      @current_page < @pages

    addThread: (thread, options) ->
      # TODO: Check for existing thread with same ID in a faster way
      if not @find(thread.id)
        options ||= {}
        model = new Thread thread
        @add model
        model

    retrieveAnotherPage: (mode, options={}, sort_options={})->
      @current_page += 1
      data = { page: @current_page }
      switch mode
        when 'search'
          url = DiscussionUtil.urlFor 'search'
          data['text'] = options.search_text
        when 'commentables'
          url = DiscussionUtil.urlFor 'search'
          data['commentable_ids'] = options.commentable_ids
        when 'all'
          url = DiscussionUtil.urlFor 'threads'
        when 'flagged'
          data['flagged'] = true
          url = DiscussionUtil.urlFor 'search'
        when 'followed'
          url = DiscussionUtil.urlFor 'followed_threads', options.user_id
      if options['group_id']
        data['group_id'] = options['group_id']
      data['sort_key'] = sort_options.sort_key || 'date'
      data['sort_order'] = sort_options.sort_order || 'desc'
      DiscussionUtil.safeAjax
        $elem: @$el
        url: url
        data: data
        dataType: 'json'
        success: (response, textStatus) =>
          models = @models
          new_threads = [new Thread(data) for data in response.discussion_data][0]
          new_collection = _.union(models, new_threads)
          Content.loadContentInfos(response.annotated_content_info)
          @reset new_collection
          @pages = response.num_pages
          @current_page = response.page

    sortByDate: (thread) ->
        #   
        #The comment client asks each thread for a value by which to sort the collection
        #and calls this sort routine regardless of the order returned from the LMS/comments service
        #so, this takes advantage of this per-thread value and returns tomorrow's date
        #for pinned threads, ensuring that they appear first, (which is the intent of pinned threads)
        #
        if thread.get('pinned')
          #use tomorrow's date
          today = new Date();
          new Date(today.getTime() + (24 * 60 * 60 * 1000));
        else
          thread.get("created_at")


    sortByDateRecentFirst: (thread) ->
        #
        #Same as above
        #but negative to flip the order (newest first)
        #
        if thread.get('pinned')
          #use tomorrow's date
          today = new Date();
          -(new Date(today.getTime() + (24 * 60 * 60 * 1000)));
        else
          -(new Date(thread.get("created_at")).getTime())
      #return String.fromCharCode.apply(String,
      #  _.map(thread.get("created_at").split(""),
      #        ((c) -> return 0xffff - c.charChodeAt()))
      #)

    sortByVotes: (thread1, thread2) ->
      thread1_count = parseInt(thread1.get("votes")['up_count'])
      thread2_count = parseInt(thread2.get("votes")['up_count'])
      if thread2_count != thread1_count
        thread2_count - thread1_count
      else
        thread2.created_at_time() - thread1.created_at_time()

    sortByComments: (thread1, thread2) ->
      thread1_count = parseInt(thread1.get("comments_count"))
      thread2_count = parseInt(thread2.get("comments_count"))
      if thread2_count != thread1_count
        thread2_count - thread1_count
      else
        thread2.created_at_time() - thread1.created_at_time()
