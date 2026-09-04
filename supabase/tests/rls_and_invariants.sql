create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select plan(19);

select has_table('public','profiles','profiles exists');
select has_table('public','activities','activities exists');
select has_table('public','friendships','friendships exists');
select has_table('public','fyrups','fyrups exists');
select has_table('public','session_invites','invites exists');
select has_index('public','activities','one_live_activity_per_user','only one LIVE activity is enforced');
select has_index('public','fyrups','fyrups_sender_id_recipient_id_sender_local_date_key','daily FYR UP uniqueness is enforced');
select policies_are('public','profiles',array['profiles_read','profiles_insert','profiles_update'],'profile RLS policies');
select policies_are('public','notifications',array['notifications_read'],'notification RLS policies');
select policies_are('public','device_tokens',array['tokens_owner'],'token RLS policy');
select has_function('public','send_friend_request',array['uuid'],'friend request RPC exists');
select has_function('public','answer_friend_request',array['uuid','boolean'],'friend answer RPC exists');
select has_function('public','block_user',array['uuid'],'block RPC exists');
select has_function('public','start_activity',array['sport_kind','text','uuid','uuid'],'activity start RPC exists');
select has_function('public','complete_activity',array['uuid','integer'],'activity completion RPC exists');
select has_function('public','plan_session',array['sport_kind','text','timestamp with time zone','smallint','text','uuid[]'],'planning RPC exists');
select has_function('public','send_fyrup',array['uuid','text'],'FYR UP RPC exists');
select has_function('public','respond_to_invite',array['uuid','invitation_status'],'invitation answer RPC exists');
select has_function('public','cancel_session',array['uuid'],'host cancellation RPC exists');

select * from finish();
rollback;
