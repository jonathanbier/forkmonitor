import React from 'react';
import {
  List,
  Datagrid,
  TextField,
  NumberField
} from 'react-admin';

import TimestampField from './timestampField';

export const BlockList = props => (
    <List {...props}
        sort={{ field: "height"}}
        >
        <Datagrid>
            <NumberField source="height" sortable={false} options={{ useGrouping: false }} />
            <TextField source="hash" sortable={false} />
            <TimestampField source="timestamp" sortable={false} />
        </Datagrid>
    </List>
);
