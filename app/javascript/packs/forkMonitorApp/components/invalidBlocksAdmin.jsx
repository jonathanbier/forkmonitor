import React from 'react';
import {
  List,
  Edit,
  SimpleForm,
  Datagrid,
  DateField,
  TextField,
  NumberField,
  DateInput
} from 'react-admin';

import TimestampField from './timestampField';

export const InvalidBlockList = props => (
    <List {...props}
        sort={{ field: "block.height"}}
        >
        <Datagrid>
            <NumberField source="block.height" sortable={false} options={{ useGrouping: false }}  />
            <TextField source="node.name_with_version" sortable={false} />
            <TextField source="block.hash" sortable={false} />
            <TimestampField source="block.timestamp" sortable={false} />
            <DateField source="dismissed_at" showTime sortable={false} />
        </Datagrid>
    </List>
);
