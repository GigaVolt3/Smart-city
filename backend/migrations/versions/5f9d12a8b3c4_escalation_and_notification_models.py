"""Escalation engine and notifications schema

Revision ID: 5f9d12a8b3c4
Revises: 35dbd88914ac
Create Date: 2026-11-08 19:50:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5f9d12a8b3c4'
down_revision: Union[str, Sequence[str], None] = '35dbd88914ac'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Update escalation_rules table
    with op.batch_alter_table('escalation_rules', schema=None) as batch_op:
        batch_op.add_column(sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()))

    # 2. Update escalation_events table
    with op.batch_alter_table('escalation_events', schema=None) as batch_op:
        batch_op.add_column(sa.Column('escalated_from_id', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('trigger_type', sa.String(length=20), nullable=False, server_default='automatic'))
        batch_op.add_column(sa.Column('deadline_exceeded_hours', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('acknowledged_at', sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column('acknowledged_by_id', sa.Integer(), nullable=True))
        batch_op.create_foreign_key('fk_escalation_events_escalated_from', 'users', ['escalated_from_id'], ['id'], ondelete='SET NULL')
        batch_op.create_foreign_key('fk_escalation_events_acknowledged_by', 'users', ['acknowledged_by_id'], ['id'], ondelete='SET NULL')
        batch_op.create_unique_constraint('uq_escalation_event_complaint_level', ['complaint_id', 'to_level'])

    # 3. Create notifications table
    op.create_table(
        'notifications',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('complaint_id', sa.Integer(), nullable=True),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('notification_type', sa.String(length=50), nullable=False, server_default='escalation'),
        sa.Column('is_read', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('read_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['complaint_id'], ['complaints.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('notifications', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_notifications_id'), ['id'], unique=False)
        batch_op.create_index(batch_op.f('ix_notifications_user_id'), ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_notifications_complaint_id'), ['complaint_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_notifications_is_read'), ['is_read'], unique=False)


def downgrade() -> None:
    # 1. Drop notifications table
    with op.batch_alter_table('notifications', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_notifications_is_read'))
        batch_op.drop_index(batch_op.f('ix_notifications_complaint_id'))
        batch_op.drop_index(batch_op.f('ix_notifications_user_id'))
        batch_op.drop_index(batch_op.f('ix_notifications_id'))
    op.drop_table('notifications')

    # 2. Revert escalation_events
    with op.batch_alter_table('escalation_events', schema=None) as batch_op:
        batch_op.drop_constraint('uq_escalation_event_complaint_level', type_='unique')
        batch_op.drop_constraint('fk_escalation_events_acknowledged_by', type_='foreignkey')
        batch_op.drop_constraint('fk_escalation_events_escalated_from', type_='foreignkey')
        batch_op.drop_column('acknowledged_by_id')
        batch_op.drop_column('acknowledged_at')
        batch_op.drop_column('deadline_exceeded_hours')
        batch_op.drop_column('trigger_type')
        batch_op.drop_column('escalated_from_id')

    # 3. Revert escalation_rules
    with op.batch_alter_table('escalation_rules', schema=None) as batch_op:
        batch_op.drop_column('is_active')

