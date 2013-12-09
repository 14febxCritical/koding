neo4j = require "neo4j"
db = new neo4j.GraphDatabase('http://localhost:7474');
# db = new neo4j.GraphDatabase('http://neo4j-dev:7474');

  # name: 'JAccount',
  # name: 'JNewApp',
  # name: 'JAppStorage' }
  # name: 'JAppStorage',
  # name: 'JCodeSnip',
  # name: 'JComment',
  # name: 'JDiscussion',
  # name: 'JEmailConfirmation',
  # name: 'JInvitation',
  # name: 'JLimit' }
  # name: 'JOpinion',
  # name: 'JPrivateMessage',
  # name: 'JReview',
  # name: 'JStatusUpdate',
  # name: 'JTag',
  # name: 'JTutorial',
  # name: 'JUser',

# query = [
#   'start koding=node:koding(\'id:*\')'
#   # 'match koding'
#   'where koding.name = "JTutorial"'
#   ' or koding.name = "JCodeSnip"'
#   ' or koding.name = "JDiscussion"'
#   ' or koding.name = "JStatusUpdate"'
#   'return koding'
#   'order by koding.`meta.createdAt` DESC'
#   'limit 10'
# ].join('\n');


# query = [
#   'start koding=node:koding(\'id:*\')'
#   'match koding-->all'
#   'where koding.name = "JTutorial"'
#   ' or koding.name = "JCodeSnip"'
#   ' or koding.name = "JDiscussion"'
#   ' or koding.name = "JStatusUpdate"'
#   'return *'
#   'order by koding.`meta.createdAt` DESC'
#   'limit 4'
# ].join('\n');

# query = [
#   'start koding=node:koding(\'id:*\')'
#   'match koding-[r:author]->all'
#   'where koding.name = "JTutorial"'
#   ' or koding.name = "JCodeSnip"'
#   ' or koding.name = "JDiscussion"'
#   ' or koding.name = "JStatusUpdate"'
#   'return type(r)'
#   'limit 400'
# ].join('\n');


# params =
#   tag : "*"
#   className : "JAccount"


# query = [
#   # 'start  koding=node:koding(id={groupId})'
#   'start koding=node:koding(\'id:5150c743f2589b107d000007\')'
#   'MATCH  koding-[:member]->members<-[:author]-content'
#   # 'where  members.name="JAccount" and r.createdAt > {startDate} and r.createdAt < {endDate}'
#   # ' where content.name = "JTutorial"'
#   # ' or content.name = "JCodeSnip"'
#   # ' or content.name = "JDiscussion"'
#   # ' or content.name = "JStatusUpdate"'
#   'return *'
#   # 'order by koding.`meta.createdAt` DESC'
#   'limit 10'
# ].join('\n');
# # query = [
# #   'start koding=node:koding(\'id:*\')'
# #   'where koding.name = "JTutorial"'
# #   ' or koding.name = "JCodeSnip"'
# #   ' or koding.name = "JDiscussion"'
# #   ' or koding.name = "JBlogPost"'
# #   ' or koding.name = "JStatusUpdate"'
# #   ' and has(koding.`meta.createdAt`)'
# #   ' and koding.`meta.createdAt` < {startDate}'
# #   'return *'
# #   'order by koding.`meta.createdAt` DESC'
# #   'limit 10'
# # ].join('\n');

# MATCH me-[rels:FRIEND*0..1]-myfriend
# WHERE me.name = 'Joe' AND ALL (r IN rels
# WHERE r.status = 'CONFIRMED')
# WITH myfriend
# MATCH myfriend-[:STATUS]-latestupdate-[:NEXT*0..1]-statusupdates
# RETURN myfriend.name AS name, statusupdates.date AS date, statusupdates.text AS text
# ORDER BY statusupdates.date DESC LIMIT 3



groupId = "5196fcb2bc9bdb0000000027"
skip = 0
limit = 33
query = """
    start  group=node:koding("id:#{groupId}")
    MATCH  group-[r:member]->members
    return members
    order by r.createdAtEpoch, members.`counts.followers` DESC
    skip #{skip}
    limit #{limit}
    """

currentUserId = "51a3e4b1db49f04a74000003"

console.time("hede")

objectify =


options =
  limitCount: 10,
  skipCount: 0,
  groupId: "5196fcb2bc9bdb0000000027",
  currentUserId: 'undefined',
  orderByQuery: 'members.`meta.modifiedAt`',
  to: undefined

options =

{ sort: { likesCount: -1 },
  limit: 8,
  skip: 0,
  originId: '5196fcb0bc9bdb0000000012',
  facets: [ 'Everything' ],
  to: 1375472260788,
  withExempt: false,
  client:
  { sessionToken: '9d0de90b6a354cfda582bc340cf4c4c6',
    context: {},
    connection: { delegate: [Object] },
    groupName: 'koding' },
  group: { groupName: 'koding', groupId: 5196fcb2bc9bdb0000000027 },
userId: '5196fcb0bc9bdb0000000012',
limitCount: 3 }


query = """
        START member=node:koding(id={userId})
        MATCH member<-[:author]-content
        WHERE content.`meta.createdAtEpoch` < {to}

        RETURN DISTINCT content
        ORDER BY coalesce(content.`meta.likes`?, 0) DESC
        LIMIT {limitCount}
    """
    # return members, count(members) as count, r
console.log query


db.query query, options, (err, results)->
  console.log err, results
  for result in results
    console.log result.members.data

# START group=node:koding("id:5196fcb2bc9bdb0000000027"), user=node:koding("id:51a3e4b1db49f04a74000003")
# MATCH group-[r:member]->members
# WHERE members-[:follower]->user
# RETURN members
# ORDER BY members.`meta.modifiedAt` DESC
# SKIP 0
# LIMIT 20



# START group=node:koding("id:5196fcb2bc9bdb0000000027")
# MATCH group-[r:member]->members-[:follower]->currentUser
# WHERE currentUser.id = "51a3e4b1db49f04a74000003"
# RETURN members
# ORDER BY members.`meta.modifiedAt` DESC
# SKIP 0
# LIMIT 20


  # koding = results.map (res) ->
  #   res['koding']

  # console.log koding
  # users = results.map (res) ->
  #   res['users']?.data

  # console.log koding.length
  # console.log new Date().getTime() - start
  # console.log koding


  # console.log users.length
  # console.log new Date().getTime() - start
  # console.log users

# start activity=node:koding('id:*') return activity.`meta.createdAt` order by activity.`meta.createdAt` DESC limit 50

"""
START koding=node:koding(id={groupId})
MATCH koding-[:member]->members<-[:author]-content
WHERE (content.name = "JTutorial"
 or content.name = "JCodeSnip"
 or content.name = "JDiscussion"
 or content.name = "JBlogPost"
 or content.name = "JStatusUpdate")
 and has(content.group)
 and content.group = "koding"
 and has(content.`meta.createdAtEpoch`)
 and content.`meta.createdAtEpoch` < {startDate}
 and content.isLowQuality! is null
return *
order by content.`meta.createdAtEpoch` DESC
limit 20 1368928928 '5196fcb2bc9bdb0000000027'

start koding=node:koding(id={groupId})
MATCH koding-[:member]->followees<-[r:follower]-follower
where followees.name="JAccount"
and follower.name="JTag"
and follower.group="koding"
and r.createdAtEpoch < {startDate}
return r,followees, follower
order by r.createdAtEpoch DESC
limit 20 1368928928

start koding=node:koding(id={groupId})
MATCH koding-[:member]->followees<-[r:follower]-follower
where followees.name="JAccount"
and follower.name="JAccount"
and r.createdAtEpoch < {startDate}
return r,followees, follower
order by r.createdAtEpoch DESC
limit 20 1368928928

START kd=node:koding(id={groupId})
MATCH kd-[:member]->users<-[r:user]-koding
WHERE koding.name="JNewApp"
and r.createdAtEpoch < {startDate}
return *
order by r.createdAtEpoch DESC
limit 20 1368928928

start  koding=node:koding(id={groupId})
MATCH  koding-[r:member]->members
where  members.name="JAccount"
and r.createdAtEpoch < {startDate}
return members
order by r.createdAtEpoch DESC
limit 20 1368928928
"""
