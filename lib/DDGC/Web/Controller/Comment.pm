package DDGC::Web::Controller::Comment;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

sub base :Chained('/base') :PathPart('comment') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
}

sub do :Chained('base') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
}

sub latest :Chained('do') :Args(0) {
	my ( $self, $c ) = @_;
	$c->pager_init($c->action,20);
	$c->stash->{latest_comments} = [($c->d->rs('Comment')->search({},{
		order_by => 'me.created',
		page => $c->stash->{page},
		rows => $c->stash->{pagesize},
	}))];
	$c->add_bc('Latest comments', $c->chained_uri('Comment','latest'));
}

sub delete : Chained('do') Args(1) {
	my ( $self, $c, $id ) = @_;
	my $comment = $c->d->rs('Comment')->prefetch_all->find($id);
	return unless $comment;
	return unless $c->user && ($c->user->admin || $c->user->id == $comment->user->id);
	if ($comment->context eq 'DDGC::DB::Result::Thread' && !$comment->parent_id) {
		$c->response->redirect($c->chained_uri(@{$comment->get_context_obj->u_delete}));
		return $c->detach;
	}
	$c->d->db->txn_do(sub {
		my $deleted_user = $c->d->db->resultset('User')->single({
			username => $c->d->config->deleted_account,
		});
		$comment->content('This comment has been deleted.');
		$comment->users_id( defined $deleted_user ? $deleted_user->id : undef );
		$comment->update;
	});
	my $redirect = $c->req->headers->referrer || '/';
	$c->response->redirect($redirect);
	return $c->detach;
}

sub add :Chained('base') :Args(2) {
	my ( $self, $c, $context, $context_id ) = @_;
	return unless $c->user || ! $c->stash->{no_reply};
	unless ($c->user) {
		$c->response->redirect($c->chained_uri('My','login'));
		return $c->detach;
	}
	if ($c->req->params->{content}) {
		$c->d->add_comment($context, $context_id, $c->user, $c->req->params->{content});
	}
	if ($c->req->params->{from}) {
		$c->response->redirect($c->req->params->{from});
		return $c->detach;
	}
}

__PACKAGE__->meta->make_immutable;

1;
